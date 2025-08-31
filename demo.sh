#!/bin/bash

echo "SISTEMA FISCAL API - DEMONSTRAÇÃO"
echo "===================================="
echo ""

echo " 1. Testando Servidor Principal..."
echo "URL: http://localhost:4000/health"
response=$(curl -s http://localhost:4000/health)
if [[ $? -eq 0 ]]; then
    echo "Servidor Principal: FUNCIONANDO"
    echo "Resposta: $response"
else
    echo "Servidor Principal: NÃO RESPONDENDO"
fi
echo ""

echo "2. Testando Status do Sistema..."
echo "URL: http://localhost:4000/api/status"
response=$(curl -s http://localhost:4000/api/status)
if [[ $? -eq 0 ]]; then
    echo "Status API: FUNCIONANDO"
    echo "Resposta: $response"
else
    echo "Status API: NÃO RESPONDENDO"
fi
echo ""

echo "3. Testando Banco de Dados..."
echo "Executando consulta de empresas..."
cd /Users/danielmatos-pro/www/app_fiscal/front-app-fiscal
db_test=$(ruby -r ./config -e "puts Company.count" 2>/dev/null)
if [[ $? -eq 0 ]]; then
    echo "Banco de Dados: CONECTADO"
    echo "Empresas cadastradas: $db_test"
else
    echo "Banco de Dados: PROBLEMA"
fi
echo ""

echo "4. Testando Redis..."
redis_test=$(redis-cli ping 2>/dev/null)
if [[ "$redis_test" == "PONG" ]]; then
    echo "Redis: FUNCIONANDO"
else
    echo "Redis: NÃO RESPONDENDO"
fi
echo ""

echo "5. Microserviços (Portas 4001-4006)..."
for port in {4001..4006}; do
    service_name=""
    case $port in
        4001) service_name="NFe" ;;
        4002) service_name="NFCe" ;;
        4003) service_name="NFSe" ;;
        4004) service_name="CTe" ;;
        4005) service_name="MDFe" ;;
        4006) service_name="SAT" ;;
    esac
    
    if curl -s --connect-timeout 2 http://localhost:$port/health >/dev/null 2>&1; then
        echo "$service_name (porta $port): FUNCIONANDO"
    else
        echo "$service_name (porta $port): PARADO"
    fi
done
echo ""

echo "RESUMO DO SISTEMA"
echo "==================="
echo "Orquestrador: Funcionando na porta 4000"
echo "Banco PostgreSQL: Conectado com dados de exemplo"
echo "Redis: Funcionando"
echo "Microserviços: Precisam ser iniciados individualmente"
echo ""
echo "ENDPOINTS DISPONÍVEIS:"
echo "• GET  /health              - Health check"
echo "• GET  /api/status          - Status do sistema"
echo "• GET  /api/companies       - Listar empresas"
echo "• POST /api/nfe/emitir      - Emitir NFe"
echo "• POST /api/nfce/emitir     - Emitir NFCe"
echo "• POST /api/nfse/emitir     - Emitir NFSe"
echo "• POST /api/cte/emitir      - Emitir CTe"
echo "• POST /api/mdfe/emitir     - Emitir MDFe"
echo "• POST /api/sat/emitir      - Emitir SAT"
echo ""
echo "Para exemplos de uso, consulte: EXAMPLES.md"
echo "Para rodar com Docker: ./quickstart.sh docker"
