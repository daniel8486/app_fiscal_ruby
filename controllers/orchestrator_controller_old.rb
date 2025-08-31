class OrchestratorController
  VALID_DOCUMENT_TYPES = %w[nfe nfce nfse cte mdfe sat].freeze
  VALID_ACTIONS = %w[emitir cancelar consultar inutilizar].freeze

  def process(data)
    AppLogger.logger.info("Iniciando processamento: #{data[:type]} - #{data[:action]}")

    # Valida entrada
    validation_result = validate_processing_data(data)
    return error_response(400, 'Dados inválidos', validation_result[:errors]) unless validation_result[:valid]

    # Verifica empresa se fornecida
    company = nil
    if data.dig(:data, :company, :cnpj)
      company = Company.by_cnpj(data[:data][:company][:cnpj]).first
      unless company
        return error_response(404, 'Empresa não encontrada',
                              "CNPJ #{data[:data][:company][:cnpj]} não cadastrado")
      end
    else
      # Usa primeira empresa disponível como padrão
      company = Company.first
      unless company
        return error_response(404, 'Nenhuma empresa cadastrada',
                              'É necessário ter pelo menos uma empresa cadastrada')
      end
    end

    # Cria registro do documento
    document = Document.create(
      document_type: data[:type],
      document_data: data[:data].to_json,
      company_id: company.id,
      status: 'pending',
      action: data[:action] || 'emitir'
    )

    # Processa baseado no tipo
    result = case data[:type]
             when 'nfe'
               process_nfe(document, company, data)
             when 'nfce'
               process_nfce(document, company, data)
             when 'nfse'
               process_nfse(document, company, data)
             when 'cte'
               process_cte(document, company, data)
             when 'mdfe'
               process_mdfe(document, company, data)
             when 'sat'
               process_sat(document, company, data)
             else
               return error_response(400, 'Tipo de documento inválido',
                                     "Tipo '#{data[:type]}' não suportado")
             end

    # Atualiza documento com resultado
    if result[:success]
      document.update_status('completed')
      document.add_sefaz_response(result[:data]) if result[:data]
      success_response(result.merge(document_id: document.id))
    else
      document.update_status('failed', result[:error])
      error_response(400, 'Erro no processamento', result[:error])
    end
  rescue StandardError => e
    AppLogger.logger.error("Erro no processamento: #{e.message}")
    AppLogger.logger.error(e.backtrace.join("\n"))
    error_response(500, 'Erro interno', e.message)
  end

  private

  def validate_processing_data(data)
    errors = []

    # Valida tipo
    unless VALID_DOCUMENT_TYPES.include?(data[:type])
      errors << "Tipo deve ser um de: #{VALID_DOCUMENT_TYPES.join(', ')}"
    end

    # Valida ação
    if data[:action] && !VALID_ACTIONS.include?(data[:action])
      errors << "Ação deve ser uma de: #{VALID_ACTIONS.join(', ')}"
    end

    # Valida dados obrigatórios
    errors << "Campo 'data' é obrigatório e deve ser um objeto" unless data[:data].is_a?(Hash)

    { valid: errors.empty?, errors: errors }
  end

  def process_nfe(document, company, data)
    service_url = 'http://localhost:4001/process'
    payload = {
      document_id: document.id,
      company: company.values,
      action: data[:action] || 'emitir',
      data: data[:data]
    }

    response = call_microservice(service_url, payload)

    if response[:success]
      {
        success: true,
        message: 'NFe processada com sucesso',
        data: response[:data],
        protocol: response[:data][:protocol],
        access_key: response[:data][:access_key]
      }
    else
      { success: false, error: response[:error] }
    end
  rescue StandardError => e
    { success: false, error: "Erro NFe: #{e.message}" }
  end

  def process_nfce(document, company, data)
    service_url = 'http://localhost:4002/process'
    payload = {
      document_id: document.id,
      company: company.values,
      action: data[:action] || 'emitir',
      data: data[:data]
    }

    response = call_microservice(service_url, payload)

    if response[:success]
      {
        success: true,
        message: 'NFCe processada com sucesso',
        data: response[:data],
        qr_code: response[:data][:qr_code],
        access_key: response[:data][:access_key]
      }
    else
      { success: false, error: response[:error] }
    end
  rescue StandardError => e
    { success: false, error: "Erro NFCe: #{e.message}" }
  end

  def process_nfse(document, company, data)
    service_url = 'http://localhost:4003/process'
    payload = {
      document_id: document.id,
      company: company.values,
      action: data[:action] || 'emitir',
      data: data[:data]
    }

    response = call_microservice(service_url, payload)

    if response[:success]
      {
        success: true,
        message: 'NFSe processada com sucesso',
        data: response[:data],
        rps_number: response[:data][:rps_number],
        verification_code: response[:data][:verification_code]
      }
    else
      { success: false, error: response[:error] }
    end
  rescue StandardError => e
    { success: false, error: "Erro NFSe: #{e.message}" }
  end

  def process_cte(document, company, data)
    service_url = 'http://localhost:4004/process'
    payload = {
      document_id: document.id,
      company: company.values,
      action: data[:action] || 'emitir',
      data: data[:data]
    }

    response = call_microservice(service_url, payload)

    if response[:success]
      {
        success: true,
        message: 'CTe processado com sucesso',
        data: response[:data],
        protocol: response[:data][:protocol],
        access_key: response[:data][:access_key]
      }
    else
      { success: false, error: response[:error] }
    end
  rescue StandardError => e
    { success: false, error: "Erro CTe: #{e.message}" }
  end

  def process_mdfe(document, company, data)
    service_url = 'http://localhost:4005/process'
    payload = {
      document_id: document.id,
      company: company.values,
      action: data[:action] || 'emitir',
      data: data[:data]
    }

    response = call_microservice(service_url, payload)

    if response[:success]
      {
        success: true,
        message: 'MDFe processado com sucesso',
        data: response[:data],
        protocol: response[:data][:protocol],
        access_key: response[:data][:access_key]
      }
    else
      { success: false, error: response[:error] }
    end
  rescue StandardError => e
    { success: false, error: "Erro MDFe: #{e.message}" }
  end

  def process_sat(document, company, data)
    service_url = 'http://localhost:4006/process'
    payload = {
      document_id: document.id,
      company: company.values,
      action: data[:action] || 'emitir',
      data: data[:data]
    }

    response = call_microservice(service_url, payload)

    if response[:success]
      {
        success: true,
        message: 'SAT processado com sucesso',
        data: response[:data],
        session_number: response[:data][:session_number],
        cupom_fiscal: response[:data][:cupom_fiscal]
      }
    else
      { success: false, error: response[:error] }
    end
  rescue StandardError => e
    { success: false, error: "Erro SAT: #{e.message}" }
  end

  def call_microservice(url, payload)
    conn = Faraday.new do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
      f.options.timeout = 30
    end

    response = conn.post(url, payload)

    if response.success?
      { success: true, data: response.body }
    else
      { success: false, error: "HTTP #{response.status}: #{response.body}" }
    end
  rescue Faraday::ConnectionFailed
    { success: false, error: "Serviço indisponível: #{url}" }
  rescue Faraday::TimeoutError
    { success: false, error: 'Timeout na comunicação com o serviço' }
  rescue StandardError => e
    { success: false, error: "Erro na comunicação: #{e.message}" }
  end

  def success_response(data)
    {
      status: 200,
      body: data.merge(
        success: true,
        timestamp: Time.now.iso8601
      ).to_json
    }
  end

  def error_response(status, message, details = nil)
    {
      status: status,
      body: {
        success: false,
        error: message,
        details: details,
        timestamp: Time.now.iso8601
      }.to_json
    }
  end

  def status(identifier)
    # Tenta buscar por process_id primeiro, depois por document_id
    process_status = Orchestrator.get_process_status(identifier)

    if process_status
      return {
        status: 200,
        body: process_status.to_json
      }
    end

    # Busca por document_id
    document = Document[identifier.to_i]
    unless document
      return {
        status: 404,
        body: {
          success: false,
          error: 'Processo não encontrado'
        }.to_json
      }
    end

    # Busca logs do processo
    process_logs = ProcessLog.by_process_id(identifier).all

    {
      status: 200,
      body: {
        document_id: document.id,
        document_status: document.status,
        document_type: document.document_type,
        created_at: document.created_at,
        updated_at: document.updated_at,
        sefaz_response: document.sefaz_response,
        error_message: document.error_message,
        process_logs: process_logs.map(&:to_hash)
      }.to_json
    }
  rescue StandardError => e
    AppLogger.error('Status check error', { identifier: identifier, error: e.message })

    {
      status: 500,
      body: {
        success: false,
        error: 'Erro ao consultar status'
      }.to_json
    }
  end

  private

  def validate_input(data)
    errors = []

    errors << 'Tipo de documento é obrigatório' unless data[:type]
    errors << 'Dados da empresa são obrigatórios' unless data[:company]
    errors << 'CNPJ da empresa é obrigatório' unless data[:company]&.dig(:cnpj)
    errors << 'Dados do documento são obrigatórios' unless data[:document]

    # Validação do tipo de documento
    valid_types = %w[nfe nfce nfse cte mdfe sat]
    unless valid_types.include?(data[:type]&.downcase)
      errors << "Tipo de documento inválido. Tipos válidos: #{valid_types.join(', ')}"
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def prepare_document_data(document, company, request_data)
    {
      id: document.id,
      type: document.document_type,
      company: {
        id: company.id,
        cnpj: company.cnpj,
        name: company.name,
        state_registration: company.state_registration,
        municipal_registration: company.municipal_registration,
        address: company.address,
        phone: company.phone,
        email: company.email,
        fiscal_regime: company.fiscal_regime,
        certificate_path: company.certificate_path
      },
      document: request_data[:document],
      certificate_password: request_data[:certificate_password]
    }
  end
end
