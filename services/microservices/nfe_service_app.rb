#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require_relative '../../lib/logger'

class NfeServiceApp < Sinatra::Base
  configure do
    set :port, ENV['NFE_SERVICE_PORT'] || 4001
    set :bind, '0.0.0.0'
    enable :logging
    set :logger, AppLogger.logger
  end

  before do
    content_type :json
    logger.info "#{request.request_method} #{request.path_info}"
  end

  # Health check
  get '/health' do
    {
      service: 'NFe Service',
      status: 'healthy',
      version: '1.0.0',
      timestamp: Time.now.iso8601,
      environment: ENV['ENVIRONMENT'] || 'development',
      capabilities: %w[emitir cancelar consultar inutilizar]
    }.to_json
  end

  # Endpoint principal de processamento
  post '/process' do
    data = JSON.parse(request.body.read, symbolize_names: true)
    logger.info "Processando NFe: #{data[:action]} - Documento ID: #{data[:document_id]}"

    case data[:action]
    when 'emitir'
      emit_nfe(data)
    when 'cancelar'
      cancel_nfe(data)
    when 'consultar'
      query_nfe(data)
    when 'inutilizar'
      inutilize_nfe(data)
    else
      error_response(400, "Ação '#{data[:action]}' não suportada")
    end
  rescue JSON::ParserError
    error_response(400, 'JSON inválido')
  rescue StandardError => e
    logger.error "Erro no processamento NFe: #{e.message}"
    error_response(500, e.message)
  end

  private

  def emit_nfe(data)
    # Simula processamento
    sleep(rand(1..3))

    # URL da SEFAZ (homologação ou produção)
    sefaz_url = ENV['SEFAZ_NFE_URL'] || 'https://homologacao.nfe.fazenda.sp.gov.br/ws/nfeautorizacao.asmx'
    logger.info "Enviando XML para SEFAZ: #{sefaz_url}"

    # Gera chave de acesso usando dados reais da empresa
    company = data.dig(:data, :company) || {}
    cnpj = company[:cnpj] || '00000000000000'
    serie = company[:serie] || '001'
    number = data.dig(:data, :numero) || rand(1..999_999)
    access_key = generate_access_key(cnpj, serie, number)

    # Alterna entre simulação local e chamada real
    if ENV['NFE_SIMULATE'] == 'true'
      # --- SIMULAÇÃO LOCAL ---
      if rand > 0.1
        {
          success: true,
          message: 'NFe autorizada com sucesso',
          protocol: "NFe#{Time.now.strftime('%Y%m%d%H%M%S')}",
          access_key: access_key,
          authorization_date: Time.now.iso8601,
          status: 'autorizada',
          sefaz_message: 'Autorizado o uso da NF-e',
          timestamp: Time.now.iso8601,
          empresa_cnpj: cnpj
        }.to_json
      else
        error_response(400, 'Rejeição SEFAZ: Duplicidade de NF-e')
      end
    else
      # --- CHAMADA REAL (comentada para testes locais) ---
      # xml = gerar_xml_nfe(data)
      # response = HTTP.post(sefaz_url, body: xml)
      # if response.status == 200
      #   # Parse da resposta real da SEFAZ
      #   {
      #     success: true,
      #     message: 'NFe autorizada pela SEFAZ',
      #     protocol: response['protocolo'],
      #     access_key: access_key,
      #     authorization_date: response['data_autorizacao'],
      #     status: response['status'],
      #     sefaz_message: response['mensagem'],
      #     timestamp: Time.now.iso8601,
      #     empresa_cnpj: cnpj
      #   }.to_json
      # else
      #   error_response(400, "Rejeição SEFAZ: #{response['mensagem']}")
      # end
      # --- FIM CHAMADA REAL ---
      # Para testes locais, mantenha a simulação ativa
      {
        success: true,
        message: 'NFe autorizada (simulação fallback)',
        protocol: "NFe#{Time.now.strftime('%Y%m%d%H%M%S')}",
        access_key: access_key,
        authorization_date: Time.now.iso8601,
        status: 'autorizada',
        sefaz_message: 'Autorizado o uso da NF-e',
        timestamp: Time.now.iso8601,
        empresa_cnpj: cnpj
      }.to_json
    end
  end

  def cancel_nfe(data)
    sleep(rand(1..2))

    if rand > 0.05 # 95% sucesso
      {
        success: true,
        message: 'NFe cancelada com sucesso',
        protocol: "CAN#{Time.now.strftime('%Y%m%d%H%M%S')}",
        access_key: data.dig(:data, :access_key),
        timestamp: Time.now.iso8601
      }.to_json
    else
      error_response(400, 'Erro no cancelamento')
    end
  end

  def query_nfe(data)
    access_key = data.dig(:data, :access_key)

    return error_response(400, 'Chave de acesso obrigatória') unless access_key

    {
      success: true,
      access_key: access_key,
      status: 'autorizada',
      protocol: "QRY#{Time.now.strftime('%Y%m%d%H%M%S')}",
      timestamp: Time.now.iso8601
    }.to_json
  end

  def inutilize_nfe(_data)
    sleep(rand(1..2))

    {
      success: true,
      message: 'Numeração inutilizada',
      protocol: "INU#{Time.now.strftime('%Y%m%d%H%M%S')}",
      timestamp: Time.now.iso8601
    }.to_json
  end

  def generate_access_key(cnpj, serie, number)
    # Simula chave de acesso NFe (44 dígitos) usando dados reais
    state_code = '35'
    emission_date = Time.now.strftime('%y%m')
    cnpj = cnpj.to_s.rjust(14, '0')
    model = '55'
    serie = serie.to_s.rjust(3, '0')
    number = number.to_s.rjust(9, '0')
    emission_type = '1'
    random_code = rand(10_000_000..99_999_999)
    dv = rand(0..9)

    "#{state_code}#{emission_date}#{cnpj}#{model}#{serie}#{number}#{emission_type}#{random_code}#{dv}"
  end

  def error_response(status, message)
    halt status, {
      success: false,
      error: message,
      timestamp: Time.now.iso8601,
      service: 'NFe Service'
    }.to_json
  end

  # Inicia o serviço se for o arquivo principal
  run! if app_file == $PROGRAM_NAME
end
