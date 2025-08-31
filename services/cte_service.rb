# frozen_string_literal: true

class CteService < BaseService
  def initialize
    super('CTe', Config.service_urls[:cte])
  end

  protected

  def validate_document_data(document_data)
    errors = []

    # Validações específicas para CTe
    document = document_data[:document]
    company = document_data[:company]

    errors << 'Dados da empresa são obrigatórios' unless company
    errors << 'CNPJ da empresa é obrigatório' unless company&.dig(:cnpj)
    errors << 'Inscrição estadual é obrigatória' unless company&.dig(:state_registration)

    errors << 'Dados do documento são obrigatórios' unless document
    errors << 'Número do CTe é obrigatório' unless document&.dig(:number)
    errors << 'Série do CTe é obrigatória' unless document&.dig(:series)
    errors << 'Remetente é obrigatório' unless document&.dig(:sender)
    errors << 'Destinatário é obrigatório' unless document&.dig(:recipient)
    errors << 'Valores do transporte são obrigatórios' unless document&.dig(:transport_values)

    # Validação do modal de transporte
    unless document&.dig(:transport_modal) && %w[01 02 03 04 05 06].include?(document[:transport_modal])
      errors << 'Modal de transporte inválido (01-Rodoviário, 02-Aéreo, 03-Aquaviário, 04-Ferroviário, 05-Dutoviário, 06-Multimodal)'
    end

    # Validação do tipo de serviço
    unless document&.dig(:service_type) && %w[0 1 2 3 4].include?(document[:service_type])
      errors << 'Tipo de serviço inválido (0-Normal, 1-Subcontratação, 2-Redespacho, 3-Intermediário, 4-Multimodal)'
    end

    # Validação dos produtos transportados
    if document&.dig(:products) && !document[:products].empty?
      document[:products].each_with_index do |product, index|
        errors << "Produto #{index + 1}: descrição é obrigatória" unless product[:description]
        errors << "Produto #{index + 1}: quantidade é obrigatória" unless product[:quantity]
        errors << "Produto #{index + 1}: valor é obrigatório" unless product[:value]
      end
    else
      errors << 'Produtos transportados são obrigatórios'
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def process_document(document_data)
    # Preparar dados para o serviço CTe
    cte_payload = prepare_cte_payload(document_data)

    # Enviar para o serviço CTe
    response = client.post('/cte/process', cte_payload)

    if response[:success]
      format_success_response({
                                protocol: response[:data][:protocol],
                                authorization_key: response[:data][:authorization_key],
                                xml_path: response[:data][:xml_path],
                                pdf_path: response[:data][:pdf_path],
                                status: 'authorized',
                                sefaz_message: response[:data][:sefaz_message],
                                tracking_code: response[:data][:tracking_code]
                              })
    else
      format_error_response(response[:error])
    end
  rescue StandardError => e
    format_error_response("CTe processing error: #{e.message}")
  end

  private

  def prepare_cte_payload(document_data)
    {
      company: {
        cnpj: document_data[:company][:cnpj],
        name: document_data[:company][:name],
        state_registration: document_data[:company][:state_registration],
        address: document_data[:company][:address],
        phone: document_data[:company][:phone]
      },
      document: {
        model: '57', # CTe
        series: document_data[:document][:series],
        number: document_data[:document][:number],
        issue_date: document_data[:document][:issue_date] || Time.now.strftime('%Y-%m-%d'),
        transport_modal: document_data[:document][:transport_modal],
        service_type: document_data[:document][:service_type],
        sender: document_data[:document][:sender],
        recipient: document_data[:document][:recipient],
        products: document_data[:document][:products],
        transport_values: document_data[:document][:transport_values],
        route: document_data[:document][:route],
        additional_info: document_data[:document][:additional_info],
        insurance: document_data[:document][:insurance] || {}
      },
      certificate: {
        path: document_data[:company][:certificate_path],
        password: document_data[:certificate_password]
      },
      environment: Config.sefaz_config[:environment]
    }
  end

  def calculate_transport_totals(transport_values, products)
    total_products = products.sum { |product| product[:value].to_f }

    {
      service_value: transport_values[:service_value].to_f,
      products_value: total_products,
      icms_base: transport_values[:service_value].to_f,
      icms_value: (transport_values[:service_value].to_f * (transport_values[:icms_rate].to_f / 100)),
      total: transport_values[:service_value].to_f + total_products
    }
  end
end
