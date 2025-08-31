# frozen_string_literal: true

class MdfeService < BaseService
  def initialize
    super('MDFe', Config.service_urls[:mdfe])
  end

  protected

  def validate_document_data(document_data)
    errors = []

    # Validações específicas para MDFe
    document = document_data[:document]
    company = document_data[:company]

    errors << 'Dados da empresa são obrigatórios' unless company
    errors << 'CNPJ da empresa é obrigatório' unless company&.dig(:cnpj)
    errors << 'Inscrição estadual é obrigatória' unless company&.dig(:state_registration)

    errors << 'Dados do documento são obrigatórios' unless document
    errors << 'Número do MDFe é obrigatório' unless document&.dig(:number)
    errors << 'Série do MDFe é obrigatória' unless document&.dig(:series)
    errors << 'Dados do condutor são obrigatórios' unless document&.dig(:driver)
    errors << 'Dados do veículo são obrigatórios' unless document&.dig(:vehicle)
    errors << 'Percurso é obrigatório' unless document&.dig(:route) && !document[:route].empty?

    # Validação do modal de transporte
    unless document&.dig(:transport_modal) && %w[01 02 03 04].include?(document[:transport_modal])
      errors << 'Modal de transporte inválido (01-Rodoviário, 02-Aéreo, 03-Aquaviário, 04-Ferroviário)'
    end

    # Validação do condutor
    driver = document&.dig(:driver)
    if driver
      errors << 'CPF do condutor é obrigatório' unless driver[:cpf]
      errors << 'Nome do condutor é obrigatório' unless driver[:name]
      errors << 'CNH do condutor é obrigatória' unless driver[:license_number]
    end

    # Validação do veículo
    vehicle = document&.dig(:vehicle)
    if vehicle
      errors << 'Placa do veículo é obrigatória' unless vehicle[:license_plate]
      errors << 'RENAVAM do veículo é obrigatório' unless vehicle[:renavam]
      errors << 'Tara do veículo é obrigatória' unless vehicle[:tare]
      errors << 'Capacidade do veículo é obrigatória' unless vehicle[:capacity]
    end

    # Validação dos documentos fiscais referenciados
    if document&.dig(:fiscal_documents)
      document[:fiscal_documents].each_with_index do |doc, index|
        errors << "Documento #{index + 1}: chave de acesso é obrigatória" unless doc[:access_key]
      end
    else
      errors << 'Documentos fiscais referenciados são obrigatórios'
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def process_document(document_data)
    # Preparar dados para o serviço MDFe
    mdfe_payload = prepare_mdfe_payload(document_data)

    # Enviar para o serviço MDFe
    response = client.post('/mdfe/process', mdfe_payload)

    if response[:success]
      format_success_response({
                                protocol: response[:data][:protocol],
                                authorization_key: response[:data][:authorization_key],
                                xml_path: response[:data][:xml_path],
                                pdf_path: response[:data][:pdf_path],
                                status: 'authorized',
                                sefaz_message: response[:data][:sefaz_message],
                                manifest_number: response[:data][:manifest_number]
                              })
    else
      format_error_response(response[:error])
    end
  rescue StandardError => e
    format_error_response("MDFe processing error: #{e.message}")
  end

  def close_manifest(access_key, closure_data)
    response = client.post('/mdfe/close', {
                             access_key: access_key,
                             closure_date: closure_data[:closure_date] || Time.now.strftime('%Y-%m-%d %H:%M:%S'),
                             municipality_code: closure_data[:municipality_code],
                             municipality_name: closure_data[:municipality_name]
                           })

    if response[:success]
      format_success_response({
                                protocol: response[:data][:protocol],
                                closure_date: response[:data][:closure_date],
                                status: 'closed'
                              })
    else
      format_error_response(response[:error])
    end
  rescue StandardError => e
    format_error_response("MDFe closure error: #{e.message}")
  end

  private

  def prepare_mdfe_payload(document_data)
    {
      company: {
        cnpj: document_data[:company][:cnpj],
        name: document_data[:company][:name],
        state_registration: document_data[:company][:state_registration],
        address: document_data[:company][:address],
        phone: document_data[:company][:phone]
      },
      document: {
        model: '58', # MDFe
        series: document_data[:document][:series],
        number: document_data[:document][:number],
        issue_date: document_data[:document][:issue_date] || Time.now.strftime('%Y-%m-%d'),
        transport_modal: document_data[:document][:transport_modal],
        driver: document_data[:document][:driver],
        vehicle: document_data[:document][:vehicle],
        route: document_data[:document][:route],
        fiscal_documents: document_data[:document][:fiscal_documents],
        cargo_info: prepare_cargo_info(document_data[:document][:fiscal_documents]),
        additional_info: document_data[:document][:additional_info]
      },
      certificate: {
        path: document_data[:company][:certificate_path],
        password: document_data[:certificate_password]
      },
      environment: Config.sefaz_config[:environment]
    }
  end

  def prepare_cargo_info(fiscal_documents)
    total_weight = fiscal_documents.sum { |doc| doc[:weight].to_f }
    total_value = fiscal_documents.sum { |doc| doc[:value].to_f }

    {
      total_weight: total_weight,
      total_value: total_value,
      cargo_type: '01', # Granel sólido, líquido ou gasoso
      unit_measure: '01' # KG
    }
  end
end
