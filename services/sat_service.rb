# frozen_string_literal: true

class SatService < BaseService
  def initialize
    super('SAT', Config.service_urls[:sat])
  end

  protected

  def validate_document_data(document_data)
    errors = []

    # Validações específicas para SAT
    document = document_data[:document]
    company = document_data[:company]

    errors << 'Dados da empresa são obrigatórios' unless company
    errors << 'CNPJ da empresa é obrigatório' unless company&.dig(:cnpj)
    errors << 'Inscrição estadual é obrigatória' unless company&.dig(:state_registration)

    errors << 'Dados do documento são obrigatórios' unless document
    errors << 'Número do CF-e SAT é obrigatório' unless document&.dig(:number)
    errors << 'Itens são obrigatórios' unless document&.dig(:items) && !document[:items].empty?
    errors << 'Forma de pagamento é obrigatória' unless document&.dig(:payments) && !document[:payments].empty?

    # Validação específica para SAT (apenas SP)
    if company&.dig(:address) && !company[:address].to_s.include?('SP')
      errors << 'SAT é válido apenas para empresas no estado de São Paulo'
    end

    # Validação dos itens
    if document&.dig(:items)
      document[:items].each_with_index do |item, index|
        errors << "Item #{index + 1}: código é obrigatório" unless item[:code]
        errors << "Item #{index + 1}: descrição é obrigatória" unless item[:description]
        errors << "Item #{index + 1}: quantidade é obrigatória" unless item[:quantity]
        errors << "Item #{index + 1}: valor unitário é obrigatório" unless item[:unit_value]
        errors << "Item #{index + 1}: NCM é obrigatório" unless item[:ncm]
        errors << "Item #{index + 1}: CFOP é obrigatório" unless item[:cfop]
      end
    end

    # Validação das formas de pagamento
    if document&.dig(:payments)
      total_payments = document[:payments].sum { |payment| payment[:value].to_f }
      total_items = document[:items].sum { |item| item[:quantity].to_f * item[:unit_value].to_f }

      unless (total_payments - total_items).abs < 0.01
        errors << 'Total dos pagamentos deve ser igual ao total dos itens'
      end
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def process_document(document_data)
    # Preparar dados para o serviço SAT
    sat_payload = prepare_sat_payload(document_data)

    # Enviar para o serviço SAT
    response = client.post('/sat/process', sat_payload)

    if response[:success]
      format_success_response({
                                sat_number: response[:data][:sat_number],
                                authorization_key: response[:data][:authorization_key],
                                xml_path: response[:data][:xml_path],
                                qr_code: response[:data][:qr_code],
                                status: 'authorized',
                                sat_message: response[:data][:sat_message],
                                session_number: response[:data][:session_number]
                              })
    else
      format_error_response(response[:error])
    end
  rescue StandardError => e
    format_error_response("SAT processing error: #{e.message}")
  end

  def cancel_document(access_key, cancellation_data)
    response = client.post('/sat/cancel', {
                             access_key: access_key,
                             cancellation_key: cancellation_data[:cancellation_key],
                             reason: cancellation_data[:reason] || 'Cancelamento solicitado pelo contribuinte'
                           })

    if response[:success]
      format_success_response({
                                cancellation_key: response[:data][:cancellation_key],
                                protocol: response[:data][:protocol],
                                cancellation_date: response[:data][:cancellation_date],
                                status: 'cancelled'
                              })
    else
      format_error_response(response[:error])
    end
  rescue StandardError => e
    format_error_response("SAT cancellation error: #{e.message}")
  end

  def check_sat_status
    response = client.get('/sat/status')

    if response[:success]
      format_success_response({
                                sat_status: response[:data][:status],
                                last_communication: response[:data][:last_communication],
                                certificate_status: response[:data][:certificate_status]
                              })
    else
      format_error_response(response[:error])
    end
  rescue StandardError => e
    format_error_response("SAT status check error: #{e.message}")
  end

  private

  def prepare_sat_payload(document_data)
    {
      company: {
        cnpj: document_data[:company][:cnpj],
        name: document_data[:company][:name],
        state_registration: document_data[:company][:state_registration],
        municipal_registration: document_data[:company][:municipal_registration],
        address: document_data[:company][:address]
      },
      document: {
        cfe_number: document_data[:document][:number],
        issue_date: document_data[:document][:issue_date] || Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        consumer: prepare_consumer_data(document_data[:document][:consumer]),
        items: document_data[:document][:items],
        payments: document_data[:document][:payments],
        totals: calculate_totals(document_data[:document][:items]),
        additional_info: document_data[:document][:additional_info]
      },
      sat_config: {
        activation_code: document_data[:sat_config][:activation_code],
        equipment_code: document_data[:sat_config][:equipment_code]
      }
    }
  end

  def prepare_consumer_data(consumer_data)
    return nil unless consumer_data

    {
      cpf_cnpj: consumer_data[:cpf] || consumer_data[:cnpj],
      name: consumer_data[:name]
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
