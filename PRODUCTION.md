# Deploy em Produção - Sistema Fiscal Ruby

## Opções de Deploy

### 1. Docker (Recomendado)

```bash
# 1. Clone o repositório
git clone <repo-url>
cd fiscal-system

# 2. Configure variáveis de ambiente
cp .env.example .env.production
# Edite .env.production com valores de produção

# 3. Configure certificados digitais
mkdir -p certificates
# Copie os arquivos .pfx das empresas para certificates/

# 4. Deploy com Docker Compose
docker-compose -f docker-compose.yml --env-file .env.production up -d

# 5. Verificar status
docker-compose ps
curl http://localhost/health
```

### 2. Kubernetes

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: fiscal-system

---
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fiscal-config
  namespace: fiscal-system
data:
  DATABASE_URL: "postgresql://user:pass@postgres:5432/fiscal_system"
  REDIS_URL: "redis://redis:6379/0"
  ENVIRONMENT: "production"

---
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fiscal-orchestrator
  namespace: fiscal-system
spec:
  replicas: 3
  selector:
    matchLabels:
      app: fiscal-orchestrator
  template:
    metadata:
      labels:
        app: fiscal-orchestrator
    spec:
      containers:
      - name: orchestrator
        image: fiscal-system:latest
        ports:
        - containerPort: 4000
        envFrom:
        - configMapRef:
            name: fiscal-config
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 5
          periodSeconds: 5
```

### 3. VPS/Servidor Dedicado

```bash
# 1. Preparar servidor (Ubuntu/CentOS)
sudo apt update && sudo apt upgrade -y

# 2. Instalar dependências
sudo apt install -y ruby-dev build-essential postgresql redis-server nginx

# 3. Configurar usuário de deploy
sudo adduser deploy
sudo usermod -aG sudo deploy
su - deploy

# 4. Instalar RVM/rbenv
curl -sSL https://get.rvm.io | bash
source ~/.rvm/scripts/rvm
rvm install 3.1.0
rvm use 3.1.0 --default

# 5. Clone e configurar aplicação
git clone <repo-url> /var/www/fiscal-system
cd /var/www/fiscal-system
bundle install --deployment --without development test

# 6. Configurar banco
sudo -u postgres createdb fiscal_system
ruby db/setup.rb

# 7. Configurar systemd
sudo cp config/systemd/* /etc/systemd/system/
sudo systemctl enable fiscal-orchestrator
sudo systemctl enable fiscal-sidekiq
sudo systemctl start fiscal-orchestrator
sudo systemctl start fiscal-sidekiq

# 8. Configurar Nginx
sudo cp nginx.conf /etc/nginx/sites-available/fiscal-system
sudo ln -s /etc/nginx/sites-available/fiscal-system /etc/nginx/sites-enabled/
sudo systemctl reload nginx
```

## Configuração de Segurança

### SSL/TLS

```bash
# 1. Instalar Certbot
sudo apt install certbot python3-certbot-nginx

# 2. Obter certificado
sudo certbot --nginx -d fiscal.suaempresa.com.br

# 3. Configurar renovação automática
sudo crontab -e
# Adicionar: 0 2 * * * certbot renew --quiet
```

### Firewall

```bash
# UFW (Ubuntu)
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw enable

# Ou iptables
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -j DROP
```

### Backup Automático

```bash
#!/bin/bash
# backup.sh - Script de backup diário

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/fiscal-system"

# Backup do banco
pg_dump fiscal_system > $BACKUP_DIR/db_$DATE.sql

# Backup dos certificados
tar -czf $BACKUP_DIR/certificates_$DATE.tar.gz certificates/

# Backup dos logs
tar -czf $BACKUP_DIR/logs_$DATE.tar.gz tmp/logs/

# Limpar backups antigos (manter 30 dias)
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup concluído: $DATE"
```

## Monitoramento

### 1. Health Checks

```bash
# Script de monitoramento
#!/bin/bash
# monitor.sh

SERVICES=(
    "http://localhost:4000/health"
    "http://localhost:4001/health"
    "http://localhost:4002/health"
    "http://localhost:4003/health"
    "http://localhost:4004/health"
    "http://localhost:4005/health"
    "http://localhost:4006/health"
)

for service in "${SERVICES[@]}"; do
    if ! curl -f -s "$service" > /dev/null; then
        echo "ALERT: $service está fora do ar!"
        # Enviar notificação (email, Slack, etc.)
    fi
done
```

### 2. Prometheus + Grafana

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'fiscal-system'
    static_configs:
    - targets: ['localhost:4000', 'localhost:4001', 'localhost:4002']
    metrics_path: '/metrics'
```

### 3. Logs Centralizados

```ruby
# config/logging.rb
require 'syslog/logger'

if ENV['ENVIRONMENT'] == 'production'
  AppLogger.logger = Syslog::Logger.new('fiscal-system')
end
```

## Configurações de Produção

### Variáveis de Ambiente (.env.production)

```bash
# Database
DATABASE_URL=postgresql://fiscal_user:secure_password@localhost:5432/fiscal_system

# Redis
REDIS_URL=redis://localhost:6379/0

# Environment
ENVIRONMENT=production
LOG_LEVEL=warn

# Security
API_SECRET_KEY=sua_chave_secreta_muito_forte_aqui
JWT_SECRET=outro_secret_muito_forte_para_jwt

# SEFAZ
SEFAZ_ENVIRONMENT=producao
SEFAZ_CERTIFICATE_PATH=/var/certificates/
SEFAZ_CERTIFICATE_PASSWORD=senha_certificado

# Timeouts
HTTP_TIMEOUT=60
SERVICE_TIMEOUT=120

# Notifications
EMAIL_NOTIFICATIONS_ENABLED=true
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=fiscal@suaempresa.com.br
SMTP_PASSWORD=senha_app_gmail

# Webhook
NOTIFICATION_WEBHOOK_URL=https://hooks.slack.com/services/...
ERROR_NOTIFICATIONS_ENABLED=true

# Performance
SIDEKIQ_CONCURRENCY=10
MAX_THREADS=5
MIN_THREADS=2
```

### Nginx Otimizado

```nginx
# /etc/nginx/sites-available/fiscal-system
upstream fiscal_app {
    least_conn;
    server 127.0.0.1:4000 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:4001 max_fails=3 fail_timeout=30s backup;
}

server {
    listen 443 ssl http2;
    server_name fiscal.suaempresa.com.br;
    
    ssl_certificate /etc/letsencrypt/live/fiscal.suaempresa.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/fiscal.suaempresa.com.br/privkey.pem;
    
    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    
    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    
    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    
    location / {
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://fiscal_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer sizes
        proxy_buffer_size 4k;
        proxy_buffers 4 4k;
        proxy_busy_buffers_size 8k;
    }
    
    # Static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check sem rate limit
    location /health {
        proxy_pass http://fiscal_app;
        access_log off;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name fiscal.suaempresa.com.br;
    return 301 https://$server_name$request_uri;
}
```

## Escalabilidade

### Load Balancer

```bash
# HAProxy configuration
global
    daemon
    maxconn 4096

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend fiscal_frontend
    bind *:80
    default_backend fiscal_backend

backend fiscal_backend
    balance roundrobin
    option httpchk GET /health
    server app1 10.0.1.10:4000 check
    server app2 10.0.1.11:4000 check
    server app3 10.0.1.12:4000 check
```

### Auto Scaling (AWS)

```json
{
  "AutoScalingGroupName": "fiscal-system-asg",
  "MinSize": 2,
  "MaxSize": 10,
  "DesiredCapacity": 3,
  "TargetGroupARNs": ["arn:aws:elasticloadbalancing:..."],
  "HealthCheckType": "ELB",
  "HealthCheckGracePeriod": 300
}
```

## Troubleshooting Produção

### Logs

```bash
# Verificar logs do sistema
journalctl -u fiscal-orchestrator -f
journalctl -u fiscal-sidekiq -f

# Logs da aplicação
tail -f /var/www/fiscal-system/tmp/logs/production.log

# Logs do Nginx
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### Performance

```bash
# Verificar uso de CPU/Memória
htop
free -h
df -h

# Verificar conexões de rede
netstat -tuln
ss -tuln

# Verificar processos Ruby
ps aux | grep ruby
```

### Banco de Dados

```sql
-- Verificar conexões ativas
SELECT * FROM pg_stat_activity;

-- Verificar queries lentas
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;

-- Verificar tamanho das tabelas
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## 📞 Suporte em Produção

### Contatos de Emergência
- DevOps: eu@danieldjam.dev.br |danielmatos404@gmail.com 
- DBA:  eu@danieldjam.dev.br |danielmatos404@gmail.com 
- Fiscal: eu@danieldjam.dev.br |danielmatos404@gmail.com 

### Procedimentos de Emergência
1. Verificar health checks
2. Consultar logs de erro
3. Verificar conectividade SEFAZ
4. Escalar para equipe responsável
5. Documentar incidente

### SLA
- Disponibilidade: 99.9%
- Tempo de resposta: < 2s
- Recuperação: < 15min
