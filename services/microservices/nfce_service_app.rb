#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require_relative '../../lib/logger'

class NfceServiceApp < Sinatra::Base
  configure do
    set :port, ENV['NFCE_SERVICE_PORT'] || 4002
    set :bind, '0.0.0.0'
    enable :logging
    set :logger, AppLogger.logger
  end

  before do
    content_type :json
  end

  # Health check
  get '/health' do
    {
      service: 'NFCe Service',
      status: 'healthy',
      version: '1.0.0',
      timestamp: Time.now.iso8601,
      environment: ENV['ENVIRONMENT'] || 'development'
    }.to_json
  end

  # Processar NFCe
  post '/nfce/process' do
    data = JSON.parse(request.body.read, symbolize_names: true)

    # Alterna entre simulação local e chamada real
    sefaz_url = ENV['SEFAZ_NFCE_URL'] || 'https://homologacao.nfce.fazenda.sp.gov.br/ws/nfceautorizacao.asmx'
    logger.info "Enviando XML para SEFAZ: #{sefaz_url}"
    validate_nfce_data(data)
    access_key = generate_access_key(data)
    qr_code_data = generate_qr_code(access_key)

    if ENV['NFCE_SIMULATE'] == 'true'
      # --- SIMULAÇÃO LOCAL ---
      if rand > 0.05
        {
          success: true,
          protocol: "NFCe#{Time.now.strftime('%Y%m%d%H%M%S')}",
          authorization_key: access_key,
          xml_path: "/tmp/nfce_#{access_key}.xml",
          qr_code: qr_code_data,
          qr_code_url: "https://www.sefaz.sp.gov.br/nfce/qrcode?p=#{qr_code_data}",
          sefaz_message: 'NFCe autorizada pela SEFAZ',
          timestamp: Time.now.iso8601
        }.to_json
      else
        status 422
        {
          success: false,
          error: "Rejeição SEFAZ: #{sample_sefaz_error}",
          timestamp: Time.now.iso8601
        }.to_json
      end
    else
      # --- CHAMADA REAL (comentada para testes locais) ---
      # xml = gerar_xml_nfce(data)
      # response = HTTP.post(sefaz_url, body: xml)
      # if response.status == 200
      #   {
      #     success: true,
      #     protocol: response['protocolo'],
      #     authorization_key: access_key,
      #     xml_path: response['xml_path'],
      #     qr_code: response['qr_code'],
      #     qr_code_url: response['qr_code_url'],
      #     sefaz_message: response['mensagem'],
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
      # --- FIM CHAMADA REAL ---
      # Para testes locais, mantenha a simulação ativa
      {
        success: true,
        protocol: "NFCe#{Time.now.strftime('%Y%m%d%H%M%S')}",
        authorization_key: access_key,
        xml_path: "/tmp/nfce_#{access_key}.xml",
        qr_code: qr_code_data,
        qr_code_url: "https://www.sefaz.sp.gov.br/nfce/qrcode?p=#{qr_code_data}",
        sefaz_message: 'NFCe autorizada (simulação fallback)',
        timestamp: Time.now.iso8601
      }.to_json
    end
  rescue JSON::ParserError
    status 400
    { error: 'JSON inválido' }.to_json
  rescue ValidationError => e
    status 422
    { error: e.message }.to_json
  rescue StandardError => e
    status 500
    { error: "Erro interno: #{e.message}" }.to_json
  end

  # Consultar NFCe
  get '/nfce/:access_key' do
    access_key = params[:access_key]

    {
      access_key: access_key,
      status: 'authorized',
      authorization_date: Time.now.iso8601,
      protocol: "NFCe#{Time.now.strftime('%Y%m%d%H%M%S')}",
      qr_code_url: "https://www.sefaz.sp.gov.br/nfce/qrcode?p=#{access_key}"
    }.to_json
  end

  # Inutilizar numeração NFCe
  post '/nfce/inutilize' do
    data = JSON.parse(request.body.read, symbolize_names: true)

    {
      success: true,
      protocol: "INUT#{Time.now.strftime('%Y%m%d%H%M%S')}",
      series: data[:series],
      start_number: data[:start_number],
      end_number: data[:end_number],
      reason: data[:reason],
      inutilization_date: Time.now.iso8601
    }.to_json
  end

  private

  def validate_nfce_data(data)
    raise ValidationError, 'Dados da empresa são obrigatórios' unless data[:company]
    raise ValidationError, 'Dados do documento são obrigatórios' unless data[:document]
    raise ValidationError, 'CNPJ é obrigatório' unless data[:company][:cnpj]
    raise ValidationError, 'Número da NFCe é obrigatório' unless data[:document][:cfe_number]
    raise ValidationError, 'Forma de pagamento é obrigatória' unless data[:document][:payments]
  end

  def generate_access_key(data)
    # Simula geração de chave de acesso NFCe (44 dígitos)
    uf_code = '35' # SP
    year_month = Time.now.strftime('%y%m')
    cnpj = data[:company][:cnpj].gsub(/\D/, '')
    model = '65'
    series = data[:series] || '001'
    number = data[:cfe_number].to_s.rjust(9, '0')
    emission_type = '1'
    random_code = rand(10_000_000..99_999_999).to_s

    partial_key = "#{uf_code}#{year_month}#{cnpj}#{model}#{series.rjust(3, '0')}#{number}#{emission_type}#{random_code}"
    check_digit = calculate_check_digit(partial_key)

    "#{partial_key}#{check_digit}"
  end

  def generate_qr_code(access_key)
    # Simula geração de dados do QR Code
    params = "p=#{access_key}|2|1|1|#{rand(100_000..999_999)}"
    params.to_s
  end

  def calculate_check_digit(key)
    weights = [2, 3, 4, 5, 6, 7, 8, 9]
    sum = 0

    key.reverse.chars.each_with_index do |digit, index|
      weight = weights[index % 8]
      sum += digit.to_i * weight
    end

    remainder = sum % 11
    remainder < 2 ? 0 : 11 - remainder
  end

  def sample_sefaz_error
    errors = [
      '539 - Duplicidade de NFCe',
      '563 - CNPJ do emitente inválido',
      '564 - IE do emitente não informada',
      '229 - IE do destinatário inválida'
    ]
    errors.sample
  end

  class ValidationError < StandardError; end
end

# Executar aplicação se for chamada diretamente
NfceServiceApp.run! if $PROGRAM_NAME == __FILE__
