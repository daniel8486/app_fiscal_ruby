#!/usr/bin/env ruby
# frozen_string_literal: true

puts '=== Teste do Ruby ==='
puts "Ruby versão: #{RUBY_VERSION}"
puts "Diretório atual: #{Dir.pwd}"

require 'sinatra'

set :port, 4000
set :bind, '0.0.0.0'

get '/health' do
  puts '=== Health check acessado ==='
  content_type :json
  '{"status":"ok","message":"Servidor funcionando"}'
end

get '/' do
  puts '=== Rota principal acessada ==='
  'Sistema Fiscal API funcionando!'
end

puts '=== Servidor iniciando na porta 4000 ==='
puts '=== Acesse http://localhost:4000 ==='
