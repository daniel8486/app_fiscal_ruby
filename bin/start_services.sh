#!/bin/bash

# Script para iniciar todos os serviços da arquitetura fiscal

set -e

echo "Iniciando Arquitetura Fiscal em Ruby"
echo "======================================="

# Função para verificar se uma porta está em uso
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        echo "Porta $port já está em uso"
        return 1
    fi
    return 0
}

# Função para iniciar um serviço
start_service() {
    local name=$1
    local port=$2
    local command=$3
    
    echo "Iniciando $name na porta $port..."
    
    if check_port $port; then
        eval "$command &"
        local pid=$!
        echo "$name iniciado (PID: $pid)"
        local name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
        echo $pid > "tmp/pids/${name_lower}.pid"
    else
        echo " Não foi possível iniciar $name - porta $port ocupada"
    fi
}

# Criar diretório para PIDs
mkdir -p tmp/pids

# Verificar dependências
echo "🔍 Verificando dependências..."

# Redis
if ! command -v redis-server &> /dev/null; then
    echo "Redis não encontrado. Instale com: brew install redis"
    exit 1
fi

# PostgreSQL
if ! command -v psql &> /dev/null; then
    echo "PostgreSQL não encontrado. Instale com: brew install postgresql"
    exit 1
fi

# Verificar se Redis está rodando
if ! redis-cli ping &> /dev/null; then
    echo "Iniciando Redis..."
    redis-server --daemonize yes
    sleep 2
fi

# Verificar se PostgreSQL está rodando
if ! pg_isready &> /dev/null; then
    echo "Iniciando PostgreSQL..."
    brew services start postgresql
    sleep 3
fi

echo " Dependências verificadas"

# Instalar gems se necessário
if [ ! -d "vendor/bundle" ]; then
    echo "Instalando gems..."
    bundle install --path vendor/bundle
fi

# Executar migrações do banco
echo "Executando migrações do banco..."
bundle exec ruby -e "
require_relative 'config'
begin
  # Criar banco se não existir
  DB.run 'SELECT 1'
  puts 'Banco de dados conectado'
rescue => e
  puts 'Erro na conexão com banco: ' + e.message
  exit 1
end
"

# Iniciar serviços
echo ""
echo "Iniciando serviços..."

# Orquestrador Principal
start_service "Orchestrator" "4000" "bundle exec ruby server.rb"

# Workers Sidekiq
# start_service "Sidekiq" "4567" "bundle exec sidekiq -r ./config.rb"

# Serviços Fiscais
start_service "NFe-Service" "4001" "bundle exec ruby services/microservices/nfe_service_app.rb"
start_service "NFCe-Service" "4002" "bundle exec ruby services/microservices/nfce_service_app.rb"
start_service "NFSe-Service" "4003" "bundle exec ruby services/microservices/nfse_service_app.rb"
start_service "CTe-Service" "4004" "bundle exec ruby services/microservices/cte_service_app.rb"
start_service "MDFe-Service" "4005" "bundle exec ruby services/microservices/mdfe_service_app.rb"
start_service "SAT-Service" "4006" "bundle exec ruby services/microservices/sat_service_app.rb"

echo ""
echo "Todos os serviços foram iniciados!"
echo ""
echo "URLs dos serviços:"
echo "• Orquestrador: http://localhost:4000"
echo "• Health Check: http://localhost:4000/health"
echo "• Sidekiq Web: http://localhost:4567"
echo "• NFe Service: http://localhost:4001"
echo "• NFCe Service: http://localhost:4002"
echo "• NFSe Service: http://localhost:4003"
echo "• CTe Service: http://localhost:4004"
echo "• MDFe Service: http://localhost:4005"
echo "• SAT Service: http://localhost:4006"
echo ""
echo "Para parar todos os serviços, execute: ./bin/stop_services.sh"
echo ""
echo "Logs dos serviços em tempo real:"
echo "   tail -f tmp/logs/*.log"
