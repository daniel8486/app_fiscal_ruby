require_relative 'workers/document_simulation_worker'
require_relative 'config'
require_relative 'controllers/certificates_controller'

class FiscalApp < Sinatra::Base
  post '/api/v1/simulate_batch' do
    payload = JSON.parse(request.body.read)
    document_type = payload['document_type'] || payload[:document_type] || 'nfe'
    company_id = payload['company_id'] || payload[:company_id] || 1
    count = (payload['count'] || payload[:count] || 50).to_i
    halt 400, { error: 'count deve ser entre 1 e 100' }.to_json if count < 1 || count > 100
    job_ids = []
    count.times do
      job_ids << DocumentSimulationWorker.perform_async(document_type, company_id)
    end
    status 202
    {
      success: true,
      message: "Simulação de #{count} envios enfileirada para #{document_type}",
      document_type: document_type,
      company_id: company_id,
      jobs: job_ids
    }.to_json
  rescue JSON::ParserError
    halt 400, { error: 'Payload inválido (JSON)' }.to_json
  end
  post '/api/v1/simulate_document' do
    payload = JSON.parse(request.body.read)
    document_type = payload['document_type'] || payload[:document_type]
    company_id = payload['company_id'] || payload[:company_id]
    halt 400, { error: 'document_type e company_id são obrigatórios' }.to_json if document_type.nil? || company_id.nil?
    DocumentSimulationWorker.perform_async(document_type, company_id)
    status 202
    {
      success: true,
      message: "Simulação de envio enfileirada para #{document_type}",
      document_type: document_type,
      company_id: company_id
    }.to_json
  rescue JSON::ParserError
    halt 400, { error: 'Payload inválido (JSON)' }.to_json
  end
  require 'prometheus/client'
  require 'prometheus/client/push'
  require 'prometheus/client/formats/text'
  # Inicializa o registro de métricas
  PROM_REGISTRY = Prometheus::Client.registry

  # Exemplo de métrica customizada
  HTTP_REQUESTS = Prometheus::Client::Counter.new(:http_requests_total, docstring: 'Contador de requisições HTTP')
  PROM_REGISTRY.register(HTTP_REQUESTS)
  require_relative 'helpers/request_id_helper'
  use CertificatesController
  register Sinatra::JSON

  configure do
    enable :logging
    set :logger, AppLogger.logger

    # CORS
    use Rack::Cors do
      allow do
        origins 'http://localhost:3000' # ou seu domínio frontend
        resource '*',
                 headers: :any,
                 methods: %i[get post put delete options],
                 credentials: true
      end
    end
  end

  before do
    content_type :json
    HTTP_REQUESTS.increment
    @request_id = RequestIdHelper.generate
    env['request_id'] = @request_id
    logger.info({
      request_id: @request_id,
      method: request.request_method,
      path: request.path_info,
      params: params
    }.to_json)
  end

  get '/metrics' do
    content_type 'text/plain'
    Prometheus::Client::Formats::Text.marshal(PROM_REGISTRY)
  end

  # Health check
  get '/api/v1/health' do
    HealthController.new.status
  end

  # Endpoint de teste
  get '/api/v1/test' do
    {
      message: 'API funcionando!',
      timestamp: Time.now.iso8601,
      version: '1.0.0',
      request_id: env['request_id']
    }.to_json
  end

  # Status geral do sistema
  get '/api/v1/status' do
    {
      orchestrator: 'running',
      database: 'connected',
      redis: 'connected',
      microservices: {
        nfe: 'running',
        nfce: 'running',
        nfse: 'running',
        cte: 'running',
        mdfe: 'running',
        sat: 'running'
      },
      timestamp: Time.now.iso8601,
      request_id: env['request_id']
    }.to_json
  end

  # Empresas
  get '/api/v1/companies' do
    companies = Company.all
    {
      companies: companies.map(&:values),
      total: companies.count,
      timestamp: Time.now.iso8601
    }.to_json
  rescue StandardError => e
    status 500
    { error: e.message, timestamp: Time.now.iso8601 }.to_json
  end

  post '/api/v1/companies' do
    require_relative 'helpers/api_error_helper'
    data = JSON.parse(request.body.read)
    company = Company.new(data)
    if company.valid?
      company.save
      status 201
      {
        company: company.values,
        message: 'Empresa criada com sucesso',
        timestamp: Time.now.iso8601
      }.to_json
    else
      status 400
      ApiErrorHelper.format(company.errors.full_messages, status: 400).to_json
    end
  end

  # NFe - Nota Fiscal Eletrônica
  post '/api/v1/nfe/emitir' do
    data = JSON.parse(request.body.read)
    result = OrchestratorController.new.process({
                                                  type: 'nfe',
                                                  action: 'emitir',
                                                  data: data
                                                })
    { result: result, timestamp: Time.now.iso8601 }.to_json
  rescue StandardError => e
    status 400
    { error: e.message, timestamp: Time.now.iso8601 }.to_json
  end

  post '/api/v1/nfe/cancelar' do
    data = JSON.parse(request.body.read)
    result = OrchestratorController.new.process({
                                                  type: 'nfe',
                                                  action: 'cancelar',
                                                  data: data
                                                })
    { result: result, timestamp: Time.now.iso8601 }.to_json
  rescue StandardError => e
    status 400
    { error: e.message, timestamp: Time.now.iso8601 }.to_json
  end

  # NFCe - Nota Fiscal de Consumidor Eletrônica
  post '/api/v1/nfce/emitir' do
    data = JSON.parse(request.body.read)
    result = OrchestratorController.new.process({
                                                  type: 'nfce',
                                                  action: 'emitir',
                                                  data: data
                                                })
    { result: result, timestamp: Time.now.iso8601 }.to_json
  rescue StandardError => e
    status 400
    { error: e.message, timestamp: Time.now.iso8601 }.to_json
  end

  # NFSe - Nota Fiscal de Serviços Eletrônica
  post '/api/v1/nfse/emitir' do
    data = JSON.parse(request.body.read)
    result = OrchestratorController.new.process({
                                                  type: 'nfse',
                                                  action: 'emitir',
                                                  data: data
                                                })
    { result: result, timestamp: Time.now.iso8601 }.to_json
  rescue StandardError => e
    status 400
    { error: e.message, timestamp: Time.now.iso8601 }.to_json
  end

  # CTe - Conhecimento de Transporte Eletrônico
  post '/api/v1/cte/emitir' do
    data = JSON.parse(request.body.read)
    result = OrchestratorController.new.process({
                                                  type: 'cte',
                                                  action: 'emitir',
                                                  data: data
                                                })
    { result: result, timestamp: Time.now.iso8601 }.to_json
  rescue StandardError => e
    status 400
    { error: e.message, timestamp: Time.now.iso8601 }.to_json
  end

  # MDFe - Manifesto de Documentos Fiscais Eletrônicos
  post '/api/v1/mdfe/emitir' do
    data = JSON.parse(request.body.read)
    result = OrchestratorController.new.process({
                                                  type: 'mdfe',
                                                  action: 'emitir',
                                                  data: data
                                                })
    { result: result, timestamp: Time.now.iso8601 }.to_json
  rescue StandardError => e
    status 400
    { error: e.message, timestamp: Time.now.iso8601 }.to_json
  end

  # SAT - Sistema Autenticador e Transmissor
  post '/api/v1/sat/emitir' do
    data = JSON.parse(request.body.read)
    result = OrchestratorController.new.process({
                                                  type: 'sat',
                                                  action: 'emitir',
                                                  data: data
                                                })
    { result: result, timestamp: Time.now.iso8601 }.to_json
  rescue StandardError => e
    status 400
    { error: e.message, timestamp: Time.now.iso8601 }.to_json
  end

  # Documentos fiscais
  get '/api/v1/documents' do
    result = DocumentsController.new.index(params)
    if result.is_a?(Array)
      status(result[0])
      headers(result[1])
      body(result[2][0])
    else
      result
    end
  end

  get '/api/v1/documents/:id' do
    result = DocumentsController.new.show(params[:id])
    if result.is_a?(Array)
      status(result[0])
      headers(result[1])
      body(result[2][0])
    else
      result
    end
  end

  post '/api/v1/documents' do
    result = DocumentsController.new.create(JSON.parse(request.body.read))
    if result.is_a?(Array)
      status(result[0])
      headers(result[1])
      body(result[2][0])
    else
      result
    end
  end

  put '/api/v1/documents/:id' do
    result = DocumentsController.new.update(params[:id], JSON.parse(request.body.read))
    if result.is_a?(Array)
      status(result[0])
      headers(result[1])
      body(result[2][0])
    else
      result
    end
  end

  delete '/api/v1/documents/:id' do
    result = DocumentsController.new.destroy(params[:id])
    if result.is_a?(Array)
      status(result[0])
      headers(result[1])
      body(result[2][0])
    else
      result
    end
  end

  # Processamento via orquestrador
  post '/api/v1/orchestrator/process' do
    result = OrchestratorController.new.process(JSON.parse(request.body.read))
    if result.is_a?(Array)
      status(result[0])
      headers(result[1])
      body(result[2][0])
    else
      result
    end
  end

  get '/api/v1/orchestrator/status/:process_id' do
    OrchestratorController.new.status(params[:process_id])
  end

  # Tratamento de erros
  error do
    status 500
    {
      error: 'Internal Server Error',
      message: env['sinatra.error'].message,
      timestamp: Time.now.iso8601,
      request_id: env['request_id']
    }.to_json
  end

  not_found do
    status 404
    {
      error: 'Not Found',
      message: 'Endpoint não encontrado',
      timestamp: Time.now.iso8601,
      request_id: env['request_id']
    }.to_json
  end
end
