#!/usr/bin/env ruby
# frozen_string_literal: true

require 'webrick'
require 'json'
require 'time'

puts 'SISTEMA FISCAL - SERVIDOR DE TESTE REAL'
puts '=========================================='

class FiscalHandler < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    case request.path
    when '/health'
      health_check(response)
    when '/api/status'
      system_status(response)
    when '/api/companies'
      list_companies(response)
    else
      not_found(response)
    end
  end

  def do_POST(request, response)
    case request.path
    when '/api/nfe/emitir'
      emit_nfe(request, response)
    when '/api/nfce/emitir'
      emit_nfce(request, response)
    when '/api/nfse/emitir'
      emit_nfse(request, response)
    when '/api/cte/emitir'
      emit_cte(request, response)
    when '/api/mdfe/emitir'
      emit_mdfe(request, response)
    when '/api/sat/emitir'
      emit_sat(request, response)
    else
      not_found(response)
    end
  end

  private

  def health_check(response)
    respond_json(response, 200, {
                   service: 'Sistema Fiscal API',
                   status: 'healthy',
                   timestamp: Time.now.iso8601,
                   version: '1.0.0'
                 })
  end

  def system_status(response)
    respond_json(response, 200, {
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
                   timestamp: Time.now.iso8601
                 })
  end

  def list_companies(response)
    companies = [
      {
        id: 1,
        name: 'Empresa Exemplo Ltda',
        cnpj: '12.345.678/0001-23',
        created_at: '2025-08-20T12:00:00-03:00'
      }
    ]

    respond_json(response, 200, {
                   companies: companies,
                   total: companies.length,
                   timestamp: Time.now.iso8601
                 })
  end

  def emit_nfe(request, response)
    data = JSON.parse(request.body, symbolize_names: true)
    puts 'NFe - Processando emissão...'
    puts "   Dados: #{data}"

    # Simula processamento
    sleep(2)

    # Gera chave de acesso
    access_key = generate_access_key('NFe')

    # Simula 90% de sucesso
    if rand > 0.1
      result = {
        success: true,
        document_type: 'NFe',
        message: 'NFe autorizada com sucesso pela SEFAZ',
        protocol: "NFe#{Time.now.strftime('%Y%m%d%H%M%S')}",
        access_key: access_key,
        authorization_date: Time.now.iso8601,
        status: 'autorizada',
        sefaz_message: 'Autorizado o uso da NF-e',
        recipient: data.dig(:data, :recipient, :name) || 'Cliente não informado',
        total_value: data.dig(:data, :total) || 0,
        xml_path: "/tmp/nfe_#{access_key}.xml",
        pdf_path: "/tmp/nfe_#{access_key}.pdf",
        processing_time: '2.1s',
        timestamp: Time.now.iso8601
      }

      puts "NFe autorizada: #{access_key}"
      respond_json(response, 200, result)
    else
      error_result = {
        success: false,
        document_type: 'NFe',
        error: 'Rejeição SEFAZ',
        code: '204',
        message: 'Duplicidade de NF-e [nRec:123456789]',
        timestamp: Time.now.iso8601
      }

      puts "NFe rejeitada: #{error_result[:message]}"
      respond_json(response, 400, error_result)
    end
  rescue JSON::ParserError
    respond_json(response, 400, {
                   success: false,
                   error: 'JSON inválido',
                   timestamp: Time.now.iso8601
                 })
  rescue StandardError => e
    puts "Erro: #{e.message}"
    respond_json(response, 500, {
                   success: false,
                   error: e.message,
                   timestamp: Time.now.iso8601
                 })
  end

  def emit_nfce(request, response)
    data = JSON.parse(request.body, symbolize_names: true)
    puts ' NFCe - Processando emissão...'

    sleep(1.5)
    access_key = generate_access_key('NFCe')

    result = {
      success: true,
      document_type: 'NFCe',
      message: 'NFCe autorizada com sucesso',
      protocol: "NFCe#{Time.now.strftime('%Y%m%d%H%M%S')}",
      access_key: access_key,
      qr_code: "https://www.fazenda.sp.gov.br/nfce/qrcode?p=#{access_key}",
      status: 'autorizada',
      total_value: data.dig(:data, :total) || 0,
      timestamp: Time.now.iso8601
    }

    puts "NFCe autorizada: #{access_key}"
    respond_json(response, 200, result)
  end

  def emit_nfse(request, response)
    data = JSON.parse(request.body, symbolize_names: true)
    puts '📄 NFSe - Processando emissão...'

    sleep(3) # NFSe demora mais
    rps_number = rand(1000..9999)

    result = {
      success: true,
      document_type: 'NFSe',
      message: 'NFSe emitida com sucesso',
      rps_number: rps_number,
      nfse_number: rand(10_000..99_999),
      verification_code: rand(10_000_000..99_999_999),
      status: 'emitida',
      service_value: data.dig(:data, :service_value) || 0,
      timestamp: Time.now.iso8601
    }

    puts "NFSe emitida: RPS #{rps_number}"
    respond_json(response, 200, result)
  end

  def emit_cte(request, response)
    data = JSON.parse(request.body, symbolize_names: true)
    puts ' CTe - Processando emissão...'

    sleep(2.5)
    access_key = generate_access_key('CTe')

    result = {
      success: true,
      document_type: 'CTe',
      message: 'CTe autorizado com sucesso',
      protocol: "CTe#{Time.now.strftime('%Y%m%d%H%M%S')}",
      access_key: access_key,
      status: 'autorizado',
      freight_value: data.dig(:data, :freight_value) || 0,
      timestamp: Time.now.iso8601
    }

    puts "CTe autorizado: #{access_key}"
    respond_json(response, 200, result)
  end

  def emit_mdfe(request, response)
    data = JSON.parse(request.body, symbolize_names: true)
    puts 'MDFe - Processando emissão...'

    sleep(2)
    access_key = generate_access_key('MDFe')

    result = {
      success: true,
      document_type: 'MDFe',
      message: 'MDFe autorizado com sucesso',
      protocol: "MDFe#{Time.now.strftime('%Y%m%d%H%M%S')}",
      access_key: access_key,
      status: 'autorizado',
      documents_count: data.dig(:data, :documents, :length) || 1,
      timestamp: Time.now.iso8601
    }

    puts "MDFe autorizado: #{access_key}"
    respond_json(response, 200, result)
  end

  def emit_sat(request, response)
    data = JSON.parse(request.body, symbolize_names: true)
    puts 'SAT - Processando emissão...'

    sleep(1)
    session_number = rand(100_000..999_999)

    result = {
      success: true,
      document_type: 'SAT',
      message: 'SAT processado com sucesso',
      session_number: session_number,
      cupom_fiscal: "SAT#{session_number}",
      status: 'autorizado',
      total_value: data.dig(:data, :total) || 0,
      timestamp: Time.now.iso8601
    }

    puts "SAT processado: #{session_number}"
    respond_json(response, 200, result)
  end

  def generate_access_key(type)
    state_code = '35' # SP
    emission_date = Time.now.strftime('%y%m')
    cnpj = '12345678000123'
    model = case type
            when 'NFe' then '55'
            when 'NFCe' then '65'
            when 'CTe' then '57'
            when 'MDFe' then '58'
            else '55'
            end
    serie = '001'
    number = rand(1..999_999).to_s.rjust(9, '0')
    emission_type = '1'
    random_code = rand(10_000_000..99_999_999)
    dv = rand(0..9)

    "#{state_code}#{emission_date}#{cnpj}#{model}#{serie}#{number}#{emission_type}#{random_code}#{dv}"
  end

  def respond_json(response, status, data)
    response.status = status
    response['Content-Type'] = 'application/json'
    response.body = data.to_json
  end

  def not_found(response)
    respond_json(response, 404, {
                   success: false,
                   error: 'Endpoint não encontrado',
                   timestamp: Time.now.iso8601
                 })
  end
end

# Configura o servidor
server = WEBrick::HTTPServer.new(
  Port: 4000,
  BindAddress: '0.0.0.0',
  Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO)
)

# Adiciona o handler
server.mount '/', FiscalHandler

# Configura shutdown
trap 'INT' do
  puts "\n Parando servidor..."
  server.shutdown
end

puts ''
puts 'Servidor rodando em: http://localhost:4000'
puts 'Endpoints disponíveis:'
puts 'GET  /health'
puts 'GET  /api/status'
puts 'GET  /api/companies'
puts 'POST /api/nfe/emitir'
puts 'POST /api/nfce/emitir'
puts 'POST /api/nfse/emitir'
puts 'POST /api/cte/emitir'
puts 'POST /api/mdfe/emitir'
puts 'POST /api/sat/emitir'
puts ''
puts 'Pronto para testes reais!'
puts ''

# Inicia o servidor
server.start
