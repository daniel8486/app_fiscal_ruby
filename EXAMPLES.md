# Exemplos de Uso da API Fiscal

## Cenário 1: Emissão de NFe Completa

```bash
# 1. Primeiro, registre uma empresa (via console ou endpoint)
curl -X POST http://localhost:4000/companies \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Tech Solutions Ltda",
    "cnpj": "12.345.678/0001-90",
    "state_registration": "123.456.789.012",
    "municipal_registration": "987654",
    "address": "Av. Paulista, 1000 - São Paulo/SP - CEP: 01310-100",
    "phone": "(11) 3333-4444",
    "email": "fiscal@techsolutions.com.br",
    "fiscal_regime": "3",
    "certificate_path": "/certificates/company.pfx"
  }'

# 2. Processar NFe
curl -X POST http://localhost:4000/orchestrator/process \
  -H "Content-Type: application/json" \
  -d '{
    "type": "nfe",
    "async": false,
    "certificate_password": "senha123",
    "company": {
      "cnpj": "12.345.678/0001-90"
    },
    "document": {
      "number": 1001,
      "series": 1,
      "issue_date": "2025-08-20",
      "operation_nature": "Venda de produtos",
      "payment_method": "01",
      "recipient": {
        "cnpj": "98.765.432/0001-10",
        "name": "Cliente Exemplo Ltda",
        "state_registration": "987.654.321.098",
        "address": {
          "street": "Rua do Cliente, 500",
          "district": "Centro",
          "city": "São Paulo",
          "state": "SP",
          "zip_code": "01234-567"
        },
        "phone": "(11) 5555-6666",
        "email": "contato@clienteexemplo.com.br"
      },
      "items": [
        {
          "code": "PROD-001",
          "description": "Notebook Dell Inspiron 15",
          "ncm": "84713012",
          "cfop": "5102",
          "unit": "UN",
          "quantity": 2,
          "unit_value": 2500.00,
          "total_value": 5000.00,
          "icms": {
            "origin": "0",
            "cst": "00",
            "rate": 18.00,
            "base": 5000.00,
            "value": 900.00
          }
        },
        {
          "code": "SERV-001", 
          "description": "Instalação e configuração",
          "ncm": "00000000",
          "cfop": "5102",
          "unit": "SV",
          "quantity": 1,
          "unit_value": 300.00,
          "total_value": 300.00,
          "icms": {
            "origin": "0",
            "cst": "41"
          }
        }
      ],
      "taxes": {
        "icms_total": 900.00,
        "products_total": 5300.00,
        "nfe_total": 5300.00
      },
      "additional_info": "Nota fiscal emitida via API - Prazo de entrega: 5 dias úteis"
    }
  }'
```

## Cenário 2: Emissão de NFCe (Cupom Fiscal)

```bash
curl -X POST http://localhost:4000/orchestrator/process \
  -H "Content-Type: application/json" \
  -d '{
    "type": "nfce",
    "async": true,
    "company": {
      "cnpj": "12.345.678/0001-90"
    },
    "document": {
      "number": 2001,
      "series": 1,
      "issue_date": "2025-08-20",
      "operation_nature": "Venda ao consumidor",
      "recipient": {
        "cpf": "123.456.789-01",
        "name": "João Silva",
        "email": "joao@email.com"
      },
      "items": [
        {
          "code": "CAFE-001",
          "description": "Café Expresso",
          "quantity": 2,
          "unit_value": 8.50,
          "cfop": "5102"
        },
        {
          "code": "SUCO-001",
          "description": "Suco de Laranja Natural",
          "quantity": 1,
          "unit_value": 12.00,
          "cfop": "5102"
        }
      ],
      "payments": [
        {
          "type": "03",
          "description": "Cartão de Crédito",
          "value": 29.00
        }
      ]
    }
  }'
```

## Cenário 3: Emissão de NFSe

```bash
curl -X POST http://localhost:4000/orchestrator/process \
  -H "Content-Type: application/json" \
  -d '{
    "type": "nfse",
    "async": true,
    "company": {
      "cnpj": "12.345.678/0001-90"
    },
    "document": {
      "number": 3001,
      "series": "1",
      "issue_date": "2025-08-20",
      "competence_date": "2025-08-20",
      "service_taker": {
        "type": "legal_entity",
        "cnpj": "98.765.432/0001-10",
        "name": "Empresa Cliente Serviços Ltda",
        "municipal_registration": "123456789",
        "address": {
          "street": "Av. Cliente, 1000",
          "district": "Empresarial",
          "city": "São Paulo",
          "state": "SP",
          "zip_code": "04567-890"
        },
        "email": "fiscal@empresacliente.com.br"
      },
      "services": [
        {
          "service_code": "01.01",
          "description": "Desenvolvimento de sistema web personalizado",
          "value": 15000.00,
          "iss_rate": 2.00,
          "city_code": "3550308"
        },
        {
          "service_code": "01.01",
          "description": "Treinamento e suporte técnico",
          "value": 3000.00,
          "iss_rate": 2.00,
          "city_code": "3550308"
        }
      ],
      "additional_info": "Projeto desenvolvido entre janeiro e agosto de 2025. Garantia de 12 meses.",
      "city_code": "3550308"
    }
  }'
```

## Cenário 4: Emissão de CTe (Transporte)

```bash
curl -X POST http://localhost:4000/orchestrator/process \
  -H "Content-Type: application/json" \
  -d '{
    "type": "cte",
    "async": true,
    "company": {
      "cnpj": "12.345.678/0001-90"
    },
    "document": {
      "number": 4001,
      "series": 1,
      "issue_date": "2025-08-20",
      "transport_modal": "01",
      "service_type": "0",
      "sender": {
        "cnpj": "11.222.333/0001-44",
        "name": "Remetente Empresa Ltda",
        "state_registration": "111.222.333.444",
        "address": {
          "street": "Rua Origem, 100",
          "city": "São Paulo",
          "state": "SP",
          "zip_code": "01000-000"
        }
      },
      "recipient": {
        "cnpj": "55.666.777/0001-88",
        "name": "Destinatário Empresa Ltda", 
        "state_registration": "555.666.777.888",
        "address": {
          "street": "Av. Destino, 500",
          "city": "Rio de Janeiro",
          "state": "RJ",
          "zip_code": "20000-000"
        }
      },
      "products": [
        {
          "description": "Equipamentos eletrônicos diversos",
          "quantity": 50,
          "weight": 1500.5,
          "value": 75000.00,
          "ncm": "84713012"
        }
      ],
      "transport_values": {
        "service_value": 2500.00,
        "icms_rate": 12.00,
        "base_value": 2500.00
      },
      "route": [
        {
          "city": "São Paulo",
          "state": "SP"
        },
        {
          "city": "Rio de Janeiro", 
          "state": "RJ"
        }
      ],
      "insurance": {
        "responsible": "1",
        "company": "Seguradora XYZ",
        "policy_number": "12345-67890",
        "value": 75000.00
      }
    }
  }'
```

## Cenário 5: Emissão de MDFe (Manifesto)

```bash
curl -X POST http://localhost:4000/orchestrator/process \
  -H "Content-Type: application/json" \
  -d '{
    "type": "mdfe",
    "async": true,
    "company": {
      "cnpj": "12.345.678/0001-90"
    },
    "document": {
      "number": 5001,
      "series": 1,
      "issue_date": "2025-08-20",
      "transport_modal": "01",
      "driver": {
        "cpf": "987.654.321-00",
        "name": "Carlos Motorista Santos",
        "license_number": "12345678901",
        "license_category": "E",
        "license_validity": "2027-12-31"
      },
      "vehicle": {
        "license_plate": "ABC-1234",
        "renavam": "123456789",
        "tare": 8000,
        "capacity": 25000,
        "vehicle_type": "02"
      },
      "route": [
        {
          "city_code": "3550308",
          "city": "São Paulo",
          "state": "SP"
        },
        {
          "city_code": "3304557", 
          "city": "Rio de Janeiro",
          "state": "RJ"
        },
        {
          "city_code": "3106200",
          "city": "Belo Horizonte", 
          "state": "MG"
        }
      ],
      "fiscal_documents": [
        {
          "access_key": "35250812345678000190550010000010011234567890",
          "weight": 500.0,
          "value": 25000.00
        },
        {
          "access_key": "35250812345678000190550010000010021234567891",
          "weight": 300.0,
          "value": 15000.00
        }
      ]
    }
  }'
```

## Cenário 6: Emissão SAT (São Paulo)

```bash
curl -X POST http://localhost:4000/orchestrator/process \
  -H "Content-Type: application/json" \
  -d '{
    "type": "sat",
    "async": true,
    "company": {
      "cnpj": "12.345.678/0001-90"
    },
    "document": {
      "number": 6001,
      "issue_date": "2025-08-20T14:30:00",
      "consumer": {
        "cpf": "123.456.789-01",
        "name": "Maria Consumidora"
      },
      "items": [
        {
          "code": "LANCHE-001",
          "description": "Hambúrguer Artesanal",
          "ncm": "21069090",
          "cfop": "5102",
          "quantity": 1,
          "unit_value": 25.90
        },
        {
          "code": "BEBIDA-001",
          "description": "Refrigerante Lata 350ml",
          "ncm": "22021000", 
          "cfop": "5102",
          "quantity": 1,
          "unit_value": 6.50
        }
      ],
      "payments": [
        {
          "type": "01",
          "description": "Dinheiro",
          "value": 32.40
        }
      ]
    },
    "sat_config": {
      "activation_code": "12345678",
      "equipment_code": "SAT001"
    }
  }'
```

## Consultas e Monitoramento

```bash
# 1. Verificar status de processamento
curl http://localhost:4000/orchestrator/status/{process_id}

# 2. Listar todos os documentos
curl "http://localhost:4000/documents?page=1&per_page=20"

# 3. Filtrar documentos por tipo
curl "http://localhost:4000/documents?type=nfe&status=completed"

# 4. Filtrar documentos por período
curl "http://localhost:4000/documents?start_date=2025-08-01&end_date=2025-08-31"

# 5. Health check geral
curl http://localhost:4000/health

# 6. Health check de serviço específico
curl http://localhost:4001/health  # NFe Service
curl http://localhost:4002/health  # NFCe Service
curl http://localhost:4003/health  # NFSe Service
```

## WebSockets para Notificações (Opcional)

```javascript
// Frontend JavaScript para receber notificações em tempo real
const ws = new WebSocket('ws://localhost:4000/notifications');

ws.onmessage = function(event) {
  const notification = JSON.parse(event.data);
  console.log('Notification:', notification);
  
  if (notification.event === 'document_processed') {
    showSuccess(`Documento ${notification.process_id} processado com sucesso!`);
  } else if (notification.event === 'document_failed') {
    showError(`Erro no documento ${notification.process_id}: ${notification.error}`);
  }
};
```

## Scripts de Teste

```bash
#!/bin/bash
# test_api.sh - Script para testar todos os endpoints

echo "Testando API Fiscal..."

# Test health
echo "Health Check..."
curl -s http://localhost:4000/health | jq .

# Test NFe
echo "Testando NFe..."
curl -X POST http://localhost:4000/orchestrator/process \
  -H "Content-Type: application/json" \
  -d @examples/nfe_example.json | jq .

# Test NFCe  
echo "Testando NFCe..."
curl -X POST http://localhost:4000/orchestrator/process \
  -H "Content-Type: application/json" \
  -d @examples/nfce_example.json | jq .

echo "Testes concluídos!"
```
