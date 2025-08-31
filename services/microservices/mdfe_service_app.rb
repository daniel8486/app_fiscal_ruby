#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require_relative '../../lib/logger'

class MdfeServiceApp < Sinatra::Base
  configure do
    set :port, ENV['MDFE_SERVICE_PORT'] || 4005
    set :bind, '0.0.0.0'
    enable :logging
    set :logger, AppLogger.logger
  end

  before do
    content_type :json
  end

  get '/health' do
    { service: 'MDFe Service', status: 'healthy', timestamp: Time.now.iso8601 }.to_json
  end

  post '/mdfe/process' do
    data = JSON.parse(request.body.read, symbolize_names: true)
    payload = data[:data] || {}
    sefaz_url = ENV['SEFAZ_MDFE_URL'] || 'https://homologacao.mdfe.fazenda.sp.gov.br/ws/mdfeautorizacao.asmx'
    logger.info "Enviando XML para SEFAZ: #{sefaz_url}"
    sleep(rand(2..4))
    access_key = "35#{Time.now.strftime('%y%m')}#{rand(10**14..10**15 - 1)}#{rand(0..9)}"

    if ENV['MDFE_SIMULATE'] == 'true'
      {
        success: true,
        protocol: "MDFe#{Time.now.strftime('%Y%m%d%H%M%S')}",
        authorization_key: access_key,
        xml_path: "/tmp/mdfe_#{access_key}.xml",
        pdf_path: "/tmp/mdfe_#{access_key}.pdf",
        sefaz_message: 'MDFe autorizado pela SEFAZ',
        manifest_number: rand(100_000..999_999),
        empresa_cnpj: payload.dig(:company, :cnpj),
        timestamp: Time.now.iso8601
      }.to_json
    else
      # --- CHAMADA REAL (comentada para testes locais) ---
      # xml = gerar_xml_mdfe(data)
      # response = HTTP.post(sefaz_url, body: xml)
      # if response.status == 200
      #   {
      #     success: true,
      #     protocol: response['protocolo'],
      #     authorization_key: access_key,
      #     xml_path: response['xml_path'],
      #     pdf_path: response['pdf_path'],
      #     sefaz_message: response['mensagem'],
      #     manifest_number: response['manifest_number'],
      #     timestamp: Time.now.iso8601
      #   }.to_json
      # else
      #   status 422
      #   {
      #     success: false,
      #     error: "Rejeição SEFAZ: #{response['mensagem']}",
      #     timestamp: Time.now.iso8601
      #   }.to_json
      # end
      {
        success: true,
        protocol: "MDFe#{Time.now.strftime('%Y%m%d%H%M%S')}",
        authorization_key: access_key,
        xml_path: "/tmp/mdfe_#{access_key}.xml",
        pdf_path: "/tmp/mdfe_#{access_key}.pdf",
        sefaz_message: 'MDFe autorizado (simulação fallback)',
        manifest_number: rand(100_000..999_999),
        timestamp: Time.now.iso8601
      }.to_json
    end
  rescue StandardError => e
    status 500
    { error: e.message }.to_json
  end

  post '/mdfe/close' do
    JSON.parse(request.body.read, symbolize_names: true)

    {
      success: true,
      protocol: "CLOSE#{Time.now.strftime('%Y%m%d%H%M%S')}",
      closure_date: Time.now.iso8601,
      timestamp: Time.now.iso8601
    }.to_json
  rescue StandardError => e
    status 500
    { error: e.message }.to_json
  end
end

MdfeServiceApp.run! if $PROGRAM_NAME == __FILE__
