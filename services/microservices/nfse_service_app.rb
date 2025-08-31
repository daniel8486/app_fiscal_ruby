#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require_relative '../../lib/logger'

class NfseServiceApp < Sinatra::Base
  configure do
    set :port, ENV['NFSE_SERVICE_PORT'] || 4003
    set :bind, '0.0.0.0'
    enable :logging
    set :logger, AppLogger.logger
  end

  before do
    content_type :json
  end

  get '/health' do
    { service: 'NFSe Service', status: 'healthy', timestamp: Time.now.iso8601 }.to_json
  end

  post '/nfse/process' do
    data = JSON.parse(request.body.read, symbolize_names: true)
    payload = data[:data] || {}
    sefaz_url = ENV['SEFAZ_NFSE_URL'] || 'https://homologacao.nfse.prefeitura.sp.gov.br/ws/nfseautorizacao.asmx'
    logger.info "Enviando XML para Prefeitura/SEFAZ: #{sefaz_url}"
    sleep(rand(2..4)) # NFSe pode demorar mais

    if ENV['NFSE_SIMULATE'] == 'true'
      {
        success: true,
        protocol: "NFSe#{Time.now.strftime('%Y%m%d%H%M%S')}",
        verification_code: rand(100_000..999_999).to_s,
        xml_path: "/tmp/nfse_#{Time.now.to_i}.xml",
        pdf_path: "/tmp/nfse_#{Time.now.to_i}.pdf",
        rps_number: payload[:rps_number],
        nfse_number: rand(1000..9999),
        city_message: 'NFSe emitida com sucesso',
        timestamp: Time.now.iso8601
      }.to_json
    else
      # --- CHAMADA REAL (comentada para testes locais) ---
      # xml = gerar_xml_nfse(data)
      # response = HTTP.post(sefaz_url, body: xml)
      # if response.status == 200
      #   {
      #     success: true,
      #     protocol: response['protocolo'],
      #     verification_code: response['verification_code'],
      #     xml_path: response['xml_path'],
      #     pdf_path: response['pdf_path'],
      #     rps_number: response['rps_number'],
      #     nfse_number: response['nfse_number'],
      #     city_message: response['mensagem'],
      #     timestamp: Time.now.iso8601
      #   }.to_json
      # else
      #   status 422
      #   {
      #     success: false,
      #     error: "Rejeição Prefeitura: #{response['mensagem']}",
      #     timestamp: Time.now.iso8601
      #   }.to_json
      # end
      {
        success: true,
        protocol: "NFSe#{Time.now.strftime('%Y%m%d%H%M%S')}",
        verification_code: rand(100_000..999_999).to_s,
        xml_path: "/tmp/nfse_#{Time.now.to_i}.xml",
        pdf_path: "/tmp/nfse_#{Time.now.to_i}.pdf",
        rps_number: data[:document][:rps_number],
        nfse_number: rand(1000..9999),
        city_message: 'NFSe emitida (simulação fallback)',
        timestamp: Time.now.iso8601
      }.to_json
    end
  rescue StandardError => e
    status 500
    { error: e.message }.to_json
  end
end

NfseServiceApp.run! if $PROGRAM_NAME == __FILE__
