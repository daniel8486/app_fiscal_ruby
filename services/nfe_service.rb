# frozen_string_literal: true

class NfeService < BaseService
  def initialize
    super('NFe', Config.service_urls[:nfe])
  end

  protected

  def validate_document_data(document_data)
    errors = []

    # Validações específicas para NFe
    document = document_data[:document]
    company = document_data[:company]

    errors << 'Dados da empresa são obrigatórios' unless company
    errors << 'CNPJ da empresa é obrigatório' unless company&.dig(:cnpj)
    errors << 'Inscrição estadual é obrigatória' unless company&.dig(:state_registration)

    errors << 'Dados do documento são obrigatórios' unless document
    errors << 'Número da NFe é obrigatório' unless document&.dig(:number)
    errors << 'Série da NFe é obrigatória' unless document&.dig(:series)
    errors << 'Destinatário é obrigatório' unless document&.dig(:recipient)
    errors << 'Itens são obrigatórios' unless document&.dig(:items) && !document[:items].empty?

    # Validação dos itens
    if document&.dig(:items)
      document[:items].each_with_index do |item, index|
        errors << "Item #{index + 1}: código é obrigatório" unless item[:code]
        errors << "Item #{index + 1}: descrição é obrigatória" unless item[:description]
        errors << "Item #{index + 1}: quantidade é obrigatória" unless item[:quantity]
        errors << "Item #{index + 1}: valor unitário é obrigatório" unless item[:unit_value]
      end
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def process_document(document_data)
    # Preparar dados para o serviço NFe
    nfe_payload = prepare_nfe_payload(document_data)

    # Enviar para o serviço NFe
    response = client.post('/nfe/process', nfe_payload)

    if response[:success]
      format_success_response({
                                protocol: response[:data][:protocol],
                                authorization_key: response[:data][:authorization_key],
                                xml_path: response[:data][:xml_path],
                                pdf_path: response[:data][:pdf_path],
                                status: 'authorized',
                                sefaz_message: response[:data][:sefaz_message]
                              })
    else
      format_error_response(response[:error])
    end
  rescue StandardError => e
    format_error_response("NFe processing error: #{e.message}")
  end

  private

  def prepare_nfe_payload(document_data)
    {
      company: {
        cnpj: document_data[:company][:cnpj],
        name: document_data[:company][:name],
        state_registration: document_data[:company][:state_registration],
        municipal_registration: document_data[:company][:municipal_registration],
        address: document_data[:company][:address],
        fiscal_regime: document_data[:company][:fiscal_regime]
      },
      document: {
        model: '55', # NFe
        series: document_data[:document][:series],
        number: document_data[:document][:number],
        issue_date: document_data[:document][:issue_date] || Time.now.strftime('%Y-%m-%d'),
        operation_nature: document_data[:document][:operation_nature] || 'Venda',
        payment_method: document_data[:document][:payment_method] || '01',
        recipient: document_data[:document][:recipient],
        items: document_data[:document][:items],
        totals: calculate_totals(document_data[:document][:items]),
        taxes: document_data[:document][:taxes] || {},
        additional_info: document_data[:document][:additional_info]
      },
      certificate: {
        path: document_data[:company][:certificate_path],
        password: document_data[:certificate_password]
      },
      environment: Config.sefaz_config[:environment]
    }
  end

  def calculate_totals(items)
    total_products = items.sum { |item| item[:quantity].to_f * item[:unit_value].to_f }

    {
      products: total_products,
      icms: 0.0, # Calcular baseado nas regras de negócio
      ipi: 0.0,  # Calcular baseado nas regras de negócio
      pis: 0.0,  # Calcular baseado nas regras de negócio
      cofins: 0.0, # Calcular baseado nas regras de negócio
      total: total_products # + impostos
    }
  end
end
