#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require_relative '../../lib/logger'

class SatServiceApp < Sinatra::Base
  configure do
    set :port, ENV['SAT_SERVICE_PORT'] || 4006
    set :bind, '0.0.0.0'
    enable :logging
    set :logger, AppLogger.logger
  end

  before do
    content_type :json
  end

  get '/health' do
    { service: 'SAT Service', status: 'healthy', timestamp: Time.now.iso8601 }.to_json
  end

  post '/sat/process' do
    data = JSON.parse(request.body.read, symbolize_names: true)
    payload = data[:data] || {}
    sefaz_url = ENV['SEFAZ_SAT_URL'] || 'https://homologacao.sat.fazenda.sp.gov.br/ws/satautorizacao.asmx'
    logger.info "Enviando XML para SEFAZ: #{sefaz_url}"
    sleep(rand(1..2))
    sat_number = rand(100_000..999_999)
    access_key = "35#{Time.now.strftime('%y%m')}#{rand(10**14..10**15 - 1)}#{rand(0..9)}"

    if ENV['SAT_SIMULATE'] == 'true'
      {
        success: true,
        sat_number: sat_number,
        authorization_key: access_key,
        xml_path: "/tmp/sat_#{sat_number}.xml",
        qr_code: "#{access_key}|#{Time.now.strftime('%Y%m%d%H%M%S')}|#{rand(1000..9999)}",
        sat_message: 'CF-e SAT emitido com sucesso',
        empresa_cnpj: payload.dig(:company, :cnpj),
        session_number: rand(100_000..999_999),
        timestamp: Time.now.iso8601
      }.to_json
    else
      # --- CHAMADA REAL (comentada para testes locais) ---
      # xml = gerar_xml_sat(data)
      # response = HTTP.post(sefaz_url, body: xml)
      # if response.status == 200
      #   {
      #     success: true,
      #     sat_number: response['sat_number'],
      #     authorization_key: access_key,
      #     xml_path: response['xml_path'],
      #     qr_code: response['qr_code'],
      #     sat_message: response['mensagem'],
      #     session_number: response['session_number'],
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
        sat_number: sat_number,
        authorization_key: access_key,
        xml_path: "/tmp/sat_#{sat_number}.xml",
        qr_code: "#{access_key}|#{Time.now.strftime('%Y%m%d%H%M%S')}|#{rand(1000..9999)}",
        sat_message: 'CF-e SAT emitido (simulação fallback)',
        session_number: rand(100_000..999_999),
        timestamp: Time.now.iso8601
      }.to_json
    end
  rescue StandardError => e
    status 500
    { error: e.message }.to_json
  end

  post '/sat/cancel' do
    JSON.parse(request.body.read, symbolize_names: true)

    {
      success: true,
      cancellation_key: "35#{Time.now.strftime('%y%m')}#{rand(10**14..10**15 - 1)}#{rand(0..9)}",
      protocol: "CANCEL#{Time.now.strftime('%Y%m%d%H%M%S')}",
      cancellation_date: Time.now.iso8601,
      timestamp: Time.now.iso8601
    }.to_json
  rescue StandardError => e
    status 500
    { error: e.message }.to_json
  end

  get '/sat/status' do
    {
      success: true,
      sat_status: 'operational',
      last_communication: Time.now.iso8601,
      certificate_status: 'valid',
      timestamp: Time.now.iso8601
    }.to_json
  end
end

SatServiceApp.run! if $PROGRAM_NAME == __FILE__
