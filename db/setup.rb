#!/usr/bin/env ruby
# frozen_string_literal: true

# Script para inicializar o banco de dados
require_relative '../config'

puts 'Inicializando banco de dados...'

begin
  # Testa conexão
  DB.test_connection
  puts 'Conexão com banco estabelecida'

  # Verifica se as tabelas já existem
  existing_tables = DB.tables

  puts "Tabelas existentes: #{existing_tables.empty? ? 'nenhuma' : existing_tables.join(', ')}"

  # Cria as tabelas se não existirem
  tables_created = []

  unless existing_tables.include?(:companies)
    puts 'Criando tabela companies...'
    require_relative '../models/company'
    tables_created << 'companies'
  end

  unless existing_tables.include?(:documents)
    puts 'Criando tabela documents...'
    require_relative '../models/document'
    tables_created << 'documents'
  end

  unless existing_tables.include?(:process_logs)
    puts 'Criando tabela process_logs...'
    require_relative '../models/process_log'
    tables_created << 'process_logs'
  end

  if tables_created.any?
    puts "Tabelas criadas: #{tables_created.join(', ')}"
  else
    puts 'Todas as tabelas já existem'
  end

  # Criar dados de exemplo (opcional)
  if ARGV.include?('--seed') || ARGV.include?('-s')
    puts 'Criando dados de exemplo...'

    # Empresa exemplo
    company = Company.find_or_create(cnpj: '12.345.678/0001-90') do |c|
      c.name = 'Empresa Exemplo Ltda'
      c.state_registration = '123.456.789.012'
      c.municipal_registration = '987654'
      c.address = 'Av. Paulista, 1000 - São Paulo/SP - CEP: 01310-100'
      c.phone = '(11) 3333-4444'
      c.email = 'fiscal@exemplo.com.br'
      c.fiscal_regime = '3'
      c.certificate_path = '/certificates/exemplo.pfx'
    end

    puts "Empresa exemplo criada: #{company.name} (ID: #{company.id})"

    # Documento exemplo
    if Document.where(company_id: company.id).count.zero?
      document = Document.create(
        document_type: 'nfe',
        document_data: {
          number: 1,
          series: 1,
          items: [
            {
              code: 'PROD001',
              description: 'Produto Exemplo',
              quantity: 1,
              unit_value: 100.00
            }
          ]
        }.to_json,
        company_id: company.id,
        status: 'draft'
      )

      puts "Documento exemplo criado (ID: #{document.id})"
    end
  end

  puts ''
  puts 'Banco de dados inicializado com sucesso!'
  puts ''
  puts 'Estatísticas:'
  puts "• Empresas: #{Company.count}"
  puts "• Documentos: #{Document.count}"
  puts "• Logs de processo: #{ProcessLog.count}"
  puts ''
  puts 'Para criar dados de exemplo, execute:'
  puts 'ruby db/setup.rb --seed'
rescue Sequel::DatabaseConnectionError => e
  puts "Erro de conexão com banco: #{e.message}"
  puts ''
  puts 'Verificações:'
  puts '1. PostgreSQL está rodando? (pg_isready)'
  puts '2. Banco existe? (createdb fiscal_system)'
  puts "3. URL está correta? (#{Config.database_url})"
  exit 1
rescue StandardError => e
  puts "Erro inesperado: #{e.message}"
  puts e.backtrace.join("\n") if ENV['DEBUG']
  exit 1
end
