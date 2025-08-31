# frozen_string_literal: true

class NfceService < BaseService
  def initialize
    super('NFCe', Config.service_urls[:nfce])
  end

  protected

  def validate_document_data(document_data)
    errors = []

    # Validações específicas para NFCe
    document = document_data[:document]
    company = document_data[:company]

    errors << 'Dados da empresa são obrigatórios' unless company
    errors << 'CNPJ da empresa é obrigatório' unless company&.dig(:cnpj)

    errors << 'Dados do documento são obrigatórios' unless document
    errors << 'Número da NFCe é obrigatório' unless document&.dig(:number)
    errors << 'Série da NFCe é obrigatória' unless document&.dig(:series)
    errors << 'Itens são obrigatórios' unless document&.dig(:items) && !document[:items].empty?

    # NFCe sempre é para consumidor final
    errors << 'Destinatário deve ser consumidor final' if document&.dig(:recipient) && document[:recipient][:cnpj]

    # Validação dos itens
    if document&.dig(:items)
      document[:items].each_with_index do |item, index|
        errors << "Item #{index + 1}: código é obrigatório" unless item[:code]
        errors << "Item #{index + 1}: descrição é obrigatória" unless item[:description]
        errors << "Item #{index + 1}: quantidade é obrigatória" unless item[:quantity]
        errors << "Item #{index + 1}: valor unitário é obrigatório" unless item[:unit_value]
      end
    end

    # Validação de forma de pagamento (obrigatória para NFCe)
    unless document&.dig(:payments) && !document[:payments].empty?
      errors << 'Forma de pagamento é obrigatória para NFCe'
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def process_document(document_data)
    # Preparar dados para o serviço NFCe
    nfce_payload = prepare_nfce_payload(document_data)

    # Enviar para o serviço NFCe
    response = client.post('/nfce/process', nfce_payload)

    if response[:success]
      format_success_response({
                                protocol: response[:data][:protocol],
                                authorization_key: response[:data][:authorization_key],
                                xml_path: response[:data][:xml_path],
                                qr_code: response[:data][:qr_code],
                                qr_code_url: response[:data][:qr_code_url],
                                status: 'authorized',
                                sefaz_message: response[:data][:sefaz_message]
                              })
    else
      format_error_response(response[:error])
    end
  rescue StandardError => e
    format_error_response("NFCe processing error: #{e.message}")
  end

  private

  def prepare_nfce_payload(document_data)
    {
      company: {
        cnpj: document_data[:company][:cnpj],
        name: document_data[:company][:name],
        state_registration: document_data[:company][:state_registration],
        address: document_data[:company][:address],
        fiscal_regime: document_data[:company][:fiscal_regime]
      },
      document: {
        model: '65', # NFCe
        series: document_data[:document][:series],
        number: document_data[:document][:number],
        issue_date: document_data[:document][:issue_date] || Time.now.strftime('%Y-%m-%d'),
        operation_nature: document_data[:document][:operation_nature] || 'Venda',
        recipient: prepare_consumer_data(document_data[:document][:recipient]),
        items: document_data[:document][:items],
        payments: document_data[:document][:payments],
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

  def prepare_consumer_data(recipient_data)
    return { consumer_type: 'final_consumer' } unless recipient_data

    {
      consumer_type: 'identified_consumer',
      cpf: recipient_data[:cpf],
      name: recipient_data[:name],
      email: recipient_data[:email]
    }
  end

  def calculate_totals(items)
    total_products = items.sum { |item| item[:quantity].to_f * item[:unit_value].to_f }

    {
      products: total_products,
      discount: 0.0,
      total: total_products
    }
  end
end
