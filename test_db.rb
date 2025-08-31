#!/usr/bin/env ruby
# frozen_string_literal: true

puts 'Testando configuração do banco...'

# Testar configuração sem carregar todos os modelos
ENV['DATABASE_URL'] = 'postgresql://danielmatos-pro@localhost:5432/fiscal_system'

begin
  require 'sequel'

  puts 'Tentando conectar ao banco...'
  db = Sequel.connect(ENV['DATABASE_URL'])

  puts 'Conexão bem-sucedida!'

  # Testar uma query simples
  result = db.fetch('SELECT 1 as test').first
  puts "Query test executada: #{result[:test]}"

  # Verificar se as tabelas existem
  tables = db.tables
  puts "Tabelas existentes: #{tables.empty? ? 'nenhuma' : tables.join(', ')}"

  # Criar tabela de teste se não existir
  unless tables.include?(:companies)
    puts 'Criando tabela companies...'
    db.create_table :companies do
      primary_key :id
      String :name, null: false
      String :cnpj, null: false, unique: true
      String :state_registration
      String :municipal_registration
      Text :address
      String :phone
      String :email
      String :fiscal_regime
      String :certificate_path
      Boolean :active, default: true
      DateTime :created_at
      DateTime :updated_at

      index :cnpj
      index :active
    end
    puts 'Tabela companies criada!'
  end

  unless tables.include?(:documents)
    puts 'Criando tabela documents...'
    db.create_table :documents do
      primary_key :id
      String :document_type, null: false
      String :status, default: 'pending'
      Text :document_data, null: false
      Text :sefaz_response
      Text :error_message
      Integer :company_id, null: false
      DateTime :created_at
      DateTime :updated_at

      index :document_type
      index :status
      index :company_id
      index :created_at
    end
    puts 'Tabela documents criada!'
  end

  unless tables.include?(:process_logs)
    puts 'Criando tabela process_logs...'
    db.create_table :process_logs do
      primary_key :id
      String :process_id, null: false
      Integer :document_id
      String :status, null: false
      Text :message
      String :service_name
      Float :execution_time
      Text :error_details
      DateTime :created_at

      index :process_id
      index :status
      index :document_id
      index :created_at
    end
    puts 'Tabela process_logs criada!'
  end

  # Inserir dados de exemplo
  companies = db[:companies]
  if companies.count.zero?
    puts 'Inserindo empresa de exemplo...'
    company_id = companies.insert(
      name: 'Empresa Exemplo Ltda',
      cnpj: '12.345.678/0001-90',
      state_registration: '123.456.789.012',
      municipal_registration: '987654',
      address: 'Av. Paulista, 1000 - São Paulo/SP - CEP: 01310-100',
      phone: '(11) 3333-4444',
      email: 'fiscal@exemplo.com.br',
      fiscal_regime: '3',
      certificate_path: '/certificates/exemplo.pfx',
      active: true,
      created_at: Time.now,
      updated_at: Time.now
    )
    puts "Empresa exemplo criada (ID: #{company_id})"
  end

  puts ''
  puts 'Banco configurado com sucesso!'
  puts 'Estatísticas:'
  puts "   • Empresas: #{db[:companies].count}"
  puts "   • Documentos: #{db[:documents].count}"
  puts "   • Logs: #{db[:process_logs].count}"
rescue StandardError => e
  puts "Erro: #{e.message}"
  puts ''
  puts 'Soluções possíveis:'
  puts '   1. Verificar se PostgreSQL está rodando: brew services start postgresql'
  puts '   2. Verificar se o banco existe: createdb fiscal_system'
  puts '   3. Verificar permissões do usuário danielmatos-pro'
  exit 1
end
