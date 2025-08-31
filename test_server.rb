#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'json'

set :port, 4000
set :bind, '0.0.0.0'

get '/health' do
  content_type :json
  { status: 'ok', timestamp: Time.now.iso8601 }.to_json
end

get '/' do
  'Sistema Fiscal API - Funcionando!'
end

puts '=== Servidor de teste iniciando na porta 4000 ==='
