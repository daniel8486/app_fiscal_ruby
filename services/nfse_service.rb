# frozen_string_literal: true

class NfseService < BaseService
  def initialize
    super('NFSe', Config.service_urls[:nfse])
  end

  protected

  def validate_document_data(document_data)
    errors = []

    # Validações específicas para NFSe
    document = document_data[:document]
    company = document_data[:company]

    errors << 'Dados da empresa são obrigatórios' unless company
    errors << 'CNPJ da empresa é obrigatório' unless company&.dig(:cnpj)
    errors << 'Inscrição municipal é obrigatória' unless company&.dig(:municipal_registration)

    errors << 'Dados do documento são obrigatórios' unless document
    errors << 'Número da NFSe é obrigatório' unless document&.dig(:number)
    errors << 'Tomador do serviço é obrigatório' unless document&.dig(:service_taker)
    errors << 'Serviços são obrigatórios' unless document&.dig(:services) && !document[:services].empty?

    # Validação dos serviços
    if document&.dig(:services)
      document[:services].each_with_index do |service, index|
        errors << "Serviço #{index + 1}: código do serviço é obrigatório" unless service[:service_code]
        errors << "Serviço #{index + 1}: descrição é obrigatória" unless service[:description]
        errors << "Serviço #{index + 1}: valor é obrigatório" unless service[:value]
        errors << "Serviço #{index + 1}: alíquota ISS é obrigatória" unless service[:iss_rate]
      end
    end

    # Validação do tomador
    service_taker = document&.dig(:service_taker)
    if service_taker
      if service_taker[:type] == 'legal_entity'
        errors << 'CNPJ do tomador é obrigatório' unless service_taker[:cnpj]
      elsif service_taker[:type] == 'individual'
        errors << 'CPF do tomador é obrigatório' unless service_taker[:cpf]
      end
      errors << 'Nome/Razão social do tomador é obrigatório' unless service_taker[:name]
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def process_document(document_data)
    # Preparar dados para o serviço NFSe
    nfse_payload = prepare_nfse_payload(document_data)

    # Enviar para o serviço NFSe
    response = client.post('/nfse/process', nfse_payload)

    if response[:success]
      format_success_response({
                                protocol: response[:data][:protocol],
                                verification_code: response[:data][:verification_code],
                                xml_path: response[:data][:xml_path],
                                pdf_path: response[:data][:pdf_path],
                                rps_number: response[:data][:rps_number],
                                nfse_number: response[:data][:nfse_number],
                                status: 'authorized',
                                city_message: response[:data][:city_message]
                              })
    else
      format_error_response(response[:error])
    end
  rescue StandardError => e
    format_error_response("NFSe processing error: #{e.message}")
  end

  private

  def prepare_nfse_payload(document_data)
    {
      company: {
        cnpj: document_data[:company][:cnpj],
        name: document_data[:company][:name],
        municipal_registration: document_data[:company][:municipal_registration],
        address: document_data[:company][:address],
        phone: document_data[:company][:phone],
        email: document_data[:company][:email]
      },
      document: {
        rps_number: document_data[:document][:number],
        rps_series: document_data[:document][:series] || '1',
        rps_type: document_data[:document][:rps_type] || '1', # RPS Normal
        issue_date: document_data[:document][:issue_date] || Time.now.strftime('%Y-%m-%d'),
        competence_date: document_data[:document][:competence_date] || Time.now.strftime('%Y-%m-%d'),
        service_taker: document_data[:document][:service_taker],
        services: document_data[:document][:services],
        totals: calculate_totals(document_data[:document][:services]),
        additional_info: document_data[:document][:additional_info],
        city_code: document_data[:document][:city_code] || extract_city_code(document_data[:company][:address])
      },
      certificate: {
        path: document_data[:company][:certificate_path],
        password: document_data[:certificate_password]
      }
    }
  end

  def calculate_totals(services)
    total_services = services.sum { |service| service[:value].to_f }
    total_iss = services.sum { |service| service[:value].to_f * (service[:iss_rate].to_f / 100) }

    {
      services: total_services,
      iss: total_iss,
      inss: 0.0, # Calcular se aplicável
      ir: 0.0,   # Calcular se aplicável
      csll: 0.0, # Calcular se aplicável
      cofins: 0.0, # Calcular se aplicável
      pis: 0.0, # Calcular se aplicável
      net_value: total_services - total_iss,
      total: total_services
    }
  end

  def extract_city_code(_address)
    # Implementar lógica para extrair código da cidade do endereço
    # Por enquanto retorna um código padrão
    '3550308' # São Paulo - SP
  end
end
