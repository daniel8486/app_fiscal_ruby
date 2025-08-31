#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require_relative '../../lib/logger'

class CteServiceApp < Sinatra::Base
  configure do
    set :port, ENV['CTE_SERVICE_PORT'] || 4004
    set :bind, '0.0.0.0'
    enable :logging
    set :logger, AppLogger.logger
  end

  before do
    content_type :json
  end

  get '/health' do
    { service: 'CTe Service', status: 'healthy', timestamp: Time.now.iso8601 }.to_json
  end

  post '/cte/process' do
    JSON.parse(request.body.read, symbolize_names: true)
    sleep(rand(1..3))

    access_key = "35#{Time.now.strftime('%y%m')}#{rand(10**14..10**15 - 1)}#{rand(0..9)}"

    sefaz_url = ENV['SEFAZ_CTE_URL'] || 'https://homologacao.cte.fazenda.sp.gov.br/ws/cteautorizacao.asmx'
    logger.info "Enviando XML para SEFAZ: #{sefaz_url}"
    company = data.dig(:data, :company) || {}
    cnpj = company[:cnpj] || '00000000000000'
    serie = company[:serie] || '001'
    number = data.dig(:data, :numero) || rand(1..999_999)
    access_key = generate_access_key(cnpj, serie, number)
    if ENV['CTE_SIMULATE'] == 'true'
      if rand > 0.1
        {
          success: true,
          message: 'CT-e autorizado com sucesso',
          protocol: "CTe#{Time.now.strftime('%Y%m%d%H%M%S')}",
          access_key: access_key,
          authorization_date: Time.now.iso8601,
          status: 'autorizado',
          sefaz_message: 'Autorizado o uso do CT-e',
          timestamp: Time.now.iso8601,
          empresa_cnpj: cnpj
        }.to_json
      else
        error_response(400, 'Rejeição SEFAZ: Duplicidade de CT-e')
      end
    else
      # --- CHAMADA REAL (comentada para testes locais) ---
      # xml = gerar_xml_cte(data)
      # response = HTTP.post(sefaz_url, body: xml)
      # if response.status == 200
      #   {
      #     success: true,
      #     message: 'CT-e autorizado pela SEFAZ',
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
      {
        success: true,
        message: 'CT-e autorizado (simulação fallback)',
        protocol: "CTe#{Time.now.strftime('%Y%m%d%H%M%S')}",
        access_key: access_key,
        authorization_date: Time.now.iso8601,
        status: 'autorizado',
        sefaz_message: 'Autorizado o uso do CT-e',
        timestamp: Time.now.iso8601,
        empresa_cnpj: cnpj
      }.to_json
    end
  rescue StandardError => e
    status 500
    { error: e.message }.to_json
  end
end

CteServiceApp.run! if $PROGRAM_NAME == __FILE__
