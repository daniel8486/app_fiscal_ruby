#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'json'

set :port, 4000
set :bind, '0.0.0.0'

get '/' do
  'Sistema Fiscal API - Servidor Principal'
end

get '/health' do
  content_type :json
  {
    status: 'ok',
    timestamp: Time.now.iso8601,
    service: 'Sistema Fiscal - Orquestrador'
  }.to_json
end

get '/test' do
  content_type :json
  {
    message: 'API funcionando!',
    timestamp: Time.now.iso8601,
    version: '1.0.0'
  }.to_json
end

get '/api/status' do
  content_type :json
  {
    orchestrator: 'running',
    database: 'connected',
    redis: 'connected',
    microservices: {
      nfe: 'stopped',
      nfce: 'stopped',
      nfse: 'stopped',
      cte: 'stopped',
      mdfe: 'stopped',
      sat: 'stopped'
    }
  }.to_json
end

puts '=== Sistema Fiscal - Servidor Principal ==='
puts 'Servidor iniciando na porta 4000...'
puts 'Acesse: http://localhost:4000'
