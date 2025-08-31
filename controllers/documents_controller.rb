# frozen_string_literal: true

class DocumentsController
  def index(params)
    require_relative '../helpers/api_error_helper'
    begin
      page = params[:page]&.to_i || 1
      per_page = params[:per_page]&.to_i || 20
      per_page = [per_page, 100].min
      documents = Document.dataset
      documents = documents.by_type(params[:type]) if params[:type]
      documents = documents.by_status(params[:status]) if params[:status]
      documents = documents.where(company_id: params[:company_id]) if params[:company_id]
      if params[:start_date] && params[:end_date]
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        documents = documents.where(created_at: start_date..end_date)
        order_by = params[:order_by] || 'created_at'
        order_direction = params[:order_direction] == 'asc' ? :asc : :desc
        documents = documents.order(Sequel.send(order_direction, order_by.to_sym))
        total_count = documents.count
        documents = documents.limit(per_page).offset((page - 1) * per_page)
        documents_with_company = documents.eager(:company).all
        def index(params)
          require_relative '../helpers/api_error_helper'
          page = params[:page]&.to_i || 1
          per_page = params[:per_page]&.to_i || 20
          per_page = [per_page, 100].min
          begin
            documents = Document.dataset
            documents = documents.by_type(params[:type]) if params[:type]
            documents = documents.by_status(params[:status]) if params[:status]
            documents = documents.where(company_id: params[:company_id]) if params[:company_id]
            if params[:start_date] && params[:end_date]
              start_date = Date.parse(params[:start_date])
              end_date = Date.parse(params[:end_date])
              documents = documents.where(created_at: start_date..end_date)
            end
            order_by = params[:order_by] || 'created_at'
            order_direction = params[:order_direction] == 'asc' ? :asc : :desc
            documents = documents.order(Sequel.send(order_direction, order_by.to_sym))
            total_count = documents.count
            documents = documents.limit(per_page).offset((page - 1) * per_page)
            documents_with_company = documents.eager(:company).all
            [
              200,
              { 'Content-Type' => 'application/json' },
              [
                {
                  success: true,
                  data: documents_with_company.map { |doc| doc.to_hash.merge(company: doc.company.to_hash) },
                  pagination: {
                    page: page,
                    per_page: per_page,
                    total_count: total_count,
                    total_pages: (total_count / per_page.to_f).ceil
                  }
                }.to_json
              ]
            ]
          rescue Date::Error
            [
              400,
              { 'Content-Type' => 'application/json' },
              [ApiErrorHelper.format('Formato de data inválido. Use YYYY-MM-DD', status: 400).to_json]
            ]
          rescue StandardError => e
            AppLogger.error('Documents index error', { error: e.message })
            [
              500,
              { 'Content-Type' => 'application/json' },
              [ApiErrorHelper.format('Erro ao listar documentos', status: 500).to_json]
            ]
          end
        end

      end
    rescue StandardError => e
      AppLogger.error('Document show error', { id: id, error: e.message })
      [
        500,
        { 'Content-Type' => 'application/json' },
        [ApiErrorHelper.format('Erro ao buscar documento', status: 500).to_json]
      ]
    end
  end

  def create(data)
    # Normaliza recebimento do payload
    require_relative '../helpers/api_error_helper'
    begin
      normalized = {}
      normalized[:document_type] = data[:document_type] || data['document_type'] || data[:type] || data['type']
      normalized[:company_cnpj] =
        data[:company_cnpj] || data['company_cnpj'] || (data[:data] && (data[:data][:company]&.dig(:cnpj) || data[:data]['company']&.dig('cnpj')))
      normalized[:document_data] = data[:document_data] || data['document_data'] || data[:data] || data['data']
      validation_result = validate_document_data(normalized)
      unless validation_result[:valid]
        return [
          400,
          { 'Content-Type' => 'application/json' },
          [ApiErrorHelper.format(validation_result[:errors], status: 400).to_json]
        ]
      end
      data = normalized
      company = Company.by_cnpj(data[:company_cnpj]).first
      unless company
        return [
          404,
          { 'Content-Type' => 'application/json' },
          [ApiErrorHelper.format('Empresa não encontrada', status: 404).to_json]
        ]
      end
      document = Document.create(
        document_type: data[:document_type],
        document_data: data[:document_data].to_json,
        company_id: company.id,
        status: 'draft'
      )

      # Integração Sidekiq: enfileira processamento conforme tipo
      case document.document_type
      when 'nfe'
        NfeServiceWorker.perform_async(document.id)
      when 'cte'
        CteServiceWorker.perform_async(document.id)
      when 'mdfe'
        MdfeServiceWorker.perform_async(document.id)
      when 'sat'
        SatServiceWorker.perform_async(document.id)
      when 'nfce'
        NfceServiceWorker.perform_async(document.id)
      when 'nfse'
        NfseServiceWorker.perform_async(document.id)
      else
        # Caso não reconhecido, loga
        AppLogger.warn('Tipo de documento não reconhecido para processamento Sidekiq',
                       { document_id: document.id, type: document.document_type })
      end
      [
        201,
        { 'Content-Type' => 'application/json' },
        [
          {
            success: true,
            data: document.to_hash.merge(company: company.to_hash)
          }.to_json
        ]
      ]
    rescue Sequel::ValidationFailed => e
      [
        400,
        { 'Content-Type' => 'application/json' },
        [ApiErrorHelper.format(e.errors, status: 400).to_json]
      ]
    rescue StandardError => e
      AppLogger.error('Document create error', { error: e.message })
      [
        500,
        { 'Content-Type' => 'application/json' },
        [ApiErrorHelper.format('Erro ao criar documento', status: 500).to_json]
      ]
    end
  end
  # Removido bloco rescue fora de método

  def destroy(id)
    require_relative '../helpers/api_error_helper'
    begin
      document = Document[id]
      unless document
        return [
          404,
          { 'Content-Type' => 'application/json' },
          [ApiErrorHelper.format('Documento não encontrado', status: 404).to_json]
        ]
      end
      unless %w[draft failed].include?(document.status)
        return [
          422,
          { 'Content-Type' => 'application/json' },
          [ApiErrorHelper.format('Documento não pode ser deletado no status atual', status: 422).to_json]
        ]
      end
      document.destroy
      [
        200,
        { 'Content-Type' => 'application/json' },
        [
          {
            success: true,
            message: 'Documento deletado com sucesso'
          }.to_json
        ]
      ]
    rescue StandardError => e
      AppLogger.error('Document delete error', { id: id, error: e.message })
      [
        500,
        { 'Content-Type' => 'application/json' },
        [ApiErrorHelper.format('Erro ao deletar documento', status: 500).to_json]
      ]
    end
  end

  private

  def validate_document_data(data)
    errors = []

    errors << 'Tipo de documento é obrigatório' unless data[:document_type]
    errors << 'CNPJ da empresa é obrigatório' unless data[:company_cnpj]
    errors << 'Dados do documento são obrigatórios' unless data[:document_data]

    # Validação do tipo de documento
    valid_types = %w[nfe nfce nfse cte mdfe sat]
    unless valid_types.include?(data[:document_type]&.downcase)
      errors << "Tipo de documento inválido. Tipos válidos: #{valid_types.join(', ')}"
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end
end
