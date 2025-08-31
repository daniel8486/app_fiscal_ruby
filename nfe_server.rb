#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'sinatra/base'
require 'json'

puts 'Iniciando NFe Service na porta 4001...'

class NfeServiceApp < Sinatra::Base
  configure do
    set :port, 4001
    set :bind, '0.0.0.0'
    enable :logging
    set :server, 'puma'
  end

  before do
    content_type :json
    puts "#{Time.now}: #{request.request_method} #{request.path_info}"
  end

  # Health check
  get '/health' do
    puts 'Health check chamado'
    response = {
      service: 'NFe Service',
      status: 'healthy',
      version: '1.0.0',
      timestamp: Time.now.iso8601,
      capabilities: %w[emitir cancelar consultar inutilizar]
    }
    puts "Respondendo: #{response}"
    response.to_json
  end

  # Endpoint principal de processamento
  post '/process' do
    puts 'Processamento iniciado'
    data = JSON.parse(request.body.read, symbolize_names: true)
    puts "Dados recebidos: #{data}"

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
  rescue JSON::ParserError => e
    puts "Erro JSON: #{e.message}"
    error_response(400, 'JSON inválido')
  rescue StandardError => e
    puts "Erro: #{e.message}"
    error_response(500, e.message)
  end

  private

  def emit_nfe(_data)
    puts 'Emitindo NFe...'
    sleep(2) # Simula processamento
    access_key = generate_access_key

    if rand > 0.1
      result = {
        success: true,
        message: 'NFe autorizada com sucesso',
        protocol: "NFe#{Time.now.strftime('%Y%m%d%H%M%S')}",
        access_key: access_key,
        status: 'autorizada',
        timestamp: Time.now.iso8601
      }
      puts "NFe emitida: #{result}"
      result.to_json
    else
      error_response(400, 'Rejeição SEFAZ: Duplicidade de NFe')
    end
  end

  def cancel_nfe(data)
    puts 'Cancelando NFe...'
    sleep(1)

    result = {
      success: true,
      message: 'NFe cancelada com sucesso',
      protocol: "CAN#{Time.now.strftime('%Y%m%d%H%M%S')}",
      access_key: data.dig(:data, :access_key),
      timestamp: Time.now.iso8601
    }
    puts "NFe cancelada: #{result}"
    result.to_json
  end

  def query_nfe(data)
    puts 'Consultando NFe...'
    access_key = data.dig(:data, :access_key)

    return error_response(400, 'Chave de acesso obrigatória') unless access_key

    result = {
      success: true,
      access_key: access_key,
      status: 'autorizada',
      protocol: "QRY#{Time.now.strftime('%Y%m%d%H%M%S')}",
      timestamp: Time.now.iso8601
    }
    puts "NFe consultada: #{result}"
    result.to_json
  end

  def inutilize_nfe(_data)
    puts 'Inutilizando NFe...'
    sleep(1)

    result = {
      success: true,
      message: 'Numeração inutilizada',
      protocol: "INU#{Time.now.strftime('%Y%m%d%H%M%S')}",
      timestamp: Time.now.iso8601
    }
    puts "NFe inutilizada: #{result}"
    result.to_json
  end

  def generate_access_key
    # Simula chave de acesso NFe (44 dígitos)
    "35#{Time.now.strftime('%y%m')}12345678000123550010000000011#{rand(10_000_000..99_999_999)}#{rand(0..9)}"
  end

  def error_response(status, message)
    puts "Erro: #{status} - #{message}"
    halt status, {
      success: false,
      error: message,
      timestamp: Time.now.iso8601
    }.to_json
  end
end

# Inicia o serviço
puts 'NFe Service rodando em: http://localhost:4001'
puts 'Health check: http://localhost:4001/health'
puts 'Processo: http://localhost:4001/process'

NfeServiceApp.run!
