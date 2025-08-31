#!/bin/bash

# Script para parar todos os serviços da arquitetura fiscal

set -e

echo "🛑 Parando Arquitetura Fiscal em Ruby"
echo "====================================="

for port in 4000 4001 4002 4003 4004 4005 4006; do
  lsof -ti tcp:$port | xargs kill -9
done

# Função para parar um serviço pelo PID
stop_service() {
    name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    pid_file="tmp/pids/${name_lower}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "🔄 Parando $name (PID: $pid)..."
            kill "$pid"
            rm "$pid_file"
            echo "✅ $name parado"
        else
            echo "⚠️  $name já estava parado"
            rm "$pid_file"
        fi
    else
        echo "⚠️  Arquivo PID não encontrado para $name"
    fi
}

# Parar todos os serviços
echo "🔄 Parando serviços..."

stop_service "Orchestrator"
stop_service "Sidekiq"
stop_service "NFe-Service"
stop_service "NFCe-Service" 
stop_service "NFSe-Service"
stop_service "CTe-Service"
stop_service "MDFe-Service"
stop_service "SAT-Service"

# Parar processos restantes na porta 4000-4006
echo "🔍 Verificando processos restantes..."
for port in {4000..4006}; do
    local pid=$(lsof -ti :$port 2>/dev/null || true)
    if [ ! -z "$pid" ]; then
        echo "🔄 Parando processo na porta $port (PID: $pid)..."
        kill "$pid" 2>/dev/null || true
    fi
done

# Limpar diretório de PIDs
rm -rf tmp/pids

echo ""
echo "✅ Todos os serviços foram parados!"
echo ""
echo "💡 Para iniciar novamente, execute: ./bin/start_services.sh"
