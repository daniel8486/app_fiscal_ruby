# Arquitetura Fiscal em Ruby

Sistema fiscal completo com orquestrador e microserviços para processamento de documentos fiscais brasileiros.

## Funcionalidades

- **NFe** - Nota Fiscal Eletrônica
- **NFCe** - Nota Fiscal de Consumidor Eletrônica  
- **NFSe** - Nota Fiscal de Serviços Eletrônica
- **CTe** - Conhecimento de Transporte Eletrônico
- **MDFe** - Manifesto Eletrônico de Documentos Fiscais
- **SAT** - Sistema Autenticador e Transmissor

## Arquitetura

```
┌─────────────────┐    ┌──────────────────────┐
│   Frontend      │────│  Orquestrador API    │
│   (React/Vue)   │    │  (Sinatra - 4000)    │
└─────────────────┘    └──────────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │     Redis       │
                       │   (Cache/Queue) │
                       └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │     Sidekiq     │
                       │   (Workers)     │
                       └─────────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          ▼                     ▼                     ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  NFe Service    │   │  NFCe Service   │   │  NFSe Service   │
│   (Port 4001)   │   │   (Port 4002)   │   │   (Port 4003)   │
└─────────────────┘   └─────────────────┘   └─────────────────┘
          ▼                     ▼                     ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  CTe Service    │   │  MDFe Service   │   │  SAT Service    │
│   (Port 4004)   │   │   (Port 4005)   │   │   (Port 4006)   │
└─────────────────┘   └─────────────────┘   └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   PostgreSQL    │
                       │   (Database)    │
                       └─────────────────┘
```

## Instalação e Execução

### Pré-requisitos

```bash
# macOS
brew install ruby redis postgresql

# Gems
gem install bundler
```

### Configuração

```bash
# 1. Clone/copie os arquivos
cd front-app-fiscal

# 2. Instale as dependências
bundle install

# 3. Configure as variáveis de ambiente
cp .env.example .env
# Edite o arquivo .env conforme necessário

# 4. Configure o banco de dados
createdb fiscal_system

# 5. Inicie os serviços
chmod +x bin/start_services.sh
./bin/start_services.sh
```

### Parar os serviços

```bash
chmod +x bin/stop_services.sh
./bin/stop_services.sh
```

## API Reference

### Health Check

```bash
curl http://localhost:4000/health
```

### Processar Documento Fiscal

```bash
curl -X POST http://localhost:4000/orchestrator/process \
  -H "Content-Type: application/json" \
  -d '{
    "type": "nfe",
    "async": true,
    "company": {
      "cnpj": "12.345.678/0001-90",
      "name": "Empresa Exemplo Ltda"
    },
    "document": {
      "number": 123,
      "series": 1,
      "items": [
        {
          "code": "PROD001",
          "description": "Produto Teste",
          "quantity": 1,
          "unit_value": 100.00
        }
      ],
      "recipient": {
        "cnpj": "98.765.432/0001-10",
        "name": "Cliente Exemplo"
      }
    }
  }'
```

### Consultar Status

```bash
curl http://localhost:4000/orchestrator/status/{process_id}
```

### Gerenciar Documentos

```bash
# Listar documentos
curl http://localhost:4000/documents

# Buscar documento específico
curl http://localhost:4000/documents/1

# Criar documento
curl -X POST http://localhost:4000/documents \
  -H "Content-Type: application/json" \
  -d '{
    "document_type": "nfe",
    "company_cnpj": "12.345.678/0001-90",
    "document_data": {
      "number": 124,
      "series": 1,
      "items": [...]
    }
  }'
```

## Configuração de Empresa

Antes de processar documentos, registre a empresa:

```bash
# Via console Ruby
bundle exec irb -r ./config.rb

# Criar empresa
company = Company.create(
  name: "Empresa Exemplo Ltda",
  cnpj: "12.345.678/0001-90",
  state_registration: "123.456.789.012",
  municipal_registration: "123456",
  address: "Rua Exemplo, 123 - São Paulo/SP",
  phone: "(11) 1234-5678",
  email: "fiscal@empresa.com.br",
  fiscal_regime: "1", # 1=Simples Nacional, 2=Simples Excesso, 3=Normal
  certificate_path: "/path/to/certificate.pfx"
)
```

## Monitoramento

- **Orquestrador**: http://localhost:4000/health
- **Sidekiq Web**: http://localhost:4567 (quando disponível)
- **Logs**: `tail -f tmp/logs/*.log`

## Segurança

- Configure certificados digitais no diretório `certificates/`
- Use variáveis de ambiente para senhas
- Implemente autenticação JWT se necessário
- Configure HTTPS em produção

## Estrutura do Projeto

```
front-app-fiscal/
├── app.rb                # Aplicação principal Sinatra
├── config.rb             # Configuração e autoload
├── server.rb             # Servidor de produção
├── config.ru             # Rack config
├── Gemfile               # Dependências Ruby
├── .env.example          # Variáveis de ambiente
├── bin/
│   ├── start_services.sh # Script de inicialização
│   └── stop_services.sh  # Script para parar serviços
├── lib/                  # Bibliotecas core
│   ├── config.rb
│   ├── logger.rb
│   ├── redis_client.rb
│   ├── service_client.rb
│   └── orchestrator.rb
├── models/               # Modelos de dados
│   ├── document.rb
│   ├── company.rb
│   └── process_log.rb
├── services/            # Serviços de negócio
│   ├── base_service.rb
│   ├── nfe_service.rb
│   ├── nfce_service.rb
│   ├── nfse_service.rb
│   ├── cte_service.rb
│   ├── mdfe_service.rb
│   ├── sat_service.rb
│   └── microservices/   # Microserviços independentes
│       ├── nfe_service_app.rb
│       ├── nfce_service_app.rb
│       ├── nfse_service_app.rb
│       ├── cte_service_app.rb
│       ├── mdfe_service_app.rb
│       └── sat_service_app.rb
├── workers/             # Workers assíncronos
│   ├── document_processor_worker.rb
│   └── notification_worker.rb
├── controllers/         # Controllers da API
│   ├── orchestrator_controller.rb
│   ├── documents_controller.rb
│   └── health_controller.rb
└── config/             # Configurações
    ├── database.rb
    └── sidekiq.rb
```

## Deploy em Produção

### Docker (Recomendado)

```dockerfile
FROM ruby:3.1
WORKDIR /app
COPY Gemfile* ./
RUN bundle install --without development test
COPY . .
EXPOSE 4000
CMD ["bundle", "exec", "ruby", "server.rb"]
```

### Systemd

```ini
[Unit]
Description=Fiscal System Orchestrator
After=redis.service postgresql.service

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/fiscal-system
ExecStart=/usr/local/bin/bundle exec ruby server.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

## Performance

- Use Redis para cache e filas
- Configure pool de conexões PostgreSQL
- Monitore workers Sidekiq
- Implemente rate limiting se necessário
- Configure load balancer para múltiplas instâncias

## Troubleshooting

### Portas ocupadas
```bash
# Verificar portas em uso
lsof -i :4000-4006

# Matar processo específico
kill -9 $(lsof -ti :4000)
```

### Redis não conecta
```bash
# Verificar se Redis está rodando
redis-cli ping

# Iniciar Redis
redis-server --daemonize yes
```

### PostgreSQL não conecta
```bash
# Verificar status
pg_isready

# Iniciar PostgreSQL
brew services start postgresql
```

## Suporte

Para questões e suporte:
- Verifique os logs em `tmp/logs/`
- Consulte o health check dos serviços
- Monitore workers Sidekiq
- Verifique conectividade com SEFAZ (em produção)

## Licença

Desenvolvimento Daniel Djam
