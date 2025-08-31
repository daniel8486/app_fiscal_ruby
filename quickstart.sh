#!/bin/bash

# Script de inicialização rápida
set -e

echo "Sistema Fiscal - Inicialização Rápida"
echo "========================================"

# Função para mostrar ajuda
show_help() {
    echo "Uso: $0 [OPÇÃO]"
    echo ""
    echo "Opções:"
    echo "  local     Inicia localmente (padrão)"
    echo "  docker    Inicia com Docker Compose"
    echo "  setup     Configura o ambiente inicial"
    echo "  test      Executa testes da API"
    echo "  help      Mostra esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0                # Inicia localmente"
    echo "  $0 docker         # Inicia com Docker"
    echo "  $0 setup          # Configura ambiente"
}

# Função para setup inicial
setup_environment() {
    echo "Configurando ambiente..."
    
    # Verificar dependências
    echo "Verificando dependências..."
    
    # Ruby
    if ! command -v ruby &> /dev/null; then
        echo "Ruby não encontrado. Instale Ruby 3.1+"
        exit 1
    fi
    
    # Bundler
    if ! command -v bundle &> /dev/null; then
        echo "Instalando Bundler..."
        gem install bundler
    fi
    
    # PostgreSQL
    if ! command -v psql &> /dev/null; then
        echo "PostgreSQL não encontrado. Instale PostgreSQL"
        echo "   macOS: brew install postgresql"
        exit 1
    fi
    
    # Redis
    if ! command -v redis-server &> /dev/null; then
        echo "Redis não encontrado. Instale Redis"
        echo "   macOS: brew install redis"
        exit 1
    fi
    
    # Instalar gems
    echo "Instalando gems Ruby..."
    bundle install
    
    # Configurar .env
    if [ ! -f .env ]; then
        echo "Criando arquivo .env..."
        cp .env.example .env
        echo "Edite o arquivo .env conforme necessário"
    fi
    
    # Configurar banco
    echo "Configurando banco de dados..."
    
    # Verificar se PostgreSQL está rodando
    if ! pg_isready &> /dev/null; then
        echo "Iniciando PostgreSQL..."
        brew services start postgresql
        sleep 3
    fi
    
    # Criar banco se não existir
    if ! psql -lqt | cut -d \| -f 1 | grep -qw fiscal_system; then
        echo "Criando banco fiscal_system..."
        createdb fiscal_system
    fi
    
    # Inicializar tabelas
    echo "Inicializando tabelas do banco..."
    ruby db/setup.rb --seed
    
    # Verificar Redis
    if ! redis-cli ping &> /dev/null; then
        echo "Iniciando Redis..."
        redis-server --daemonize yes
        sleep 2
    fi
    
    echo ""
    echo "Ambiente configurado com sucesso!"
    echo ""
    echo "Para iniciar o sistema:"
    echo "   ./quickstart.sh local    # Localmente"
    echo "   ./quickstart.sh docker   # Com Docker"
}

# Função para iniciar localmente
start_local() {
    echo "Iniciando sistema localmente..."
    
    # Verificar se setup foi feito
    if [ ! -f .env ] || [ ! -f Gemfile.lock ]; then
        echo "Ambiente não configurado. Executando setup..."
        setup_environment
    fi
    
    # Iniciar serviços
    chmod +x bin/start_services.sh
    ./bin/start_services.sh
}

# Função para iniciar com Docker
start_docker() {
    echo "Iniciando com Docker Compose..."
    
    # Verificar se Docker está instalado
    if ! command -v docker &> /dev/null; then
        echo "Docker não encontrado. Instale Docker Desktop"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "Docker Compose não encontrado"
        exit 1
    fi
    
    # Criar diretórios necessários
    mkdir -p certificates tmp/logs ssl
    
    # Buildar e iniciar
    echo "Buildando imagens..."
    docker-compose build
    
    echo "Iniciando serviços..."
    docker-compose up -d
    
    echo ""
    echo "Serviços Docker iniciados!"
    echo ""
    echo "Para acompanhar logs:"
    echo "   docker-compose logs -f"
    echo ""
    echo "Para parar:"
    echo "   docker-compose down"
}

# Função para testar API
test_api() {
    echo "Testando API..."
    
    # Verificar se jq está instalado
    if ! command -v jq &> /dev/null; then
        echo "Instale 'jq' para melhor formatação: brew install jq"
        JQ_CMD="cat"
    else
        JQ_CMD="jq ."
    fi
    
    # Health check
    echo "Health Check..."
    curl -s http://localhost:4000/health | $JQ_CMD
    echo ""
    
    # Testar serviços individuais
    for port in {4001..4006}; do
        echo "🔍 Testando serviço na porta $port..."
        curl -s http://localhost:$port/health | $JQ_CMD || echo " Serviço indisponível"
        echo ""
    done
    
    echo "Testes concluídos!"
}

# Processar argumentos
case "${1:-local}" in
    local)
        start_local
        ;;
    docker)
        start_docker
        ;;
    setup)
        setup_environment
        ;;
    test)
        test_api
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Opção inválida: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
