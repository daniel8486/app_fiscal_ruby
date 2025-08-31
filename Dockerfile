# Dockerfile para o Sistema Fiscal
FROM ruby:3.1-alpine

# Instalar dependências do sistema
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    tzdata \
    bash \
    curl

# Configurar diretório de trabalho
WORKDIR /app

# Copiar Gemfile e instalar gems
COPY Gemfile Gemfile.lock ./
RUN bundle config --global frozen 1 && \
    bundle install --without development test

# Copiar código da aplicação
COPY . .

# Criar diretórios necessários
RUN mkdir -p tmp/pids tmp/logs certificates

# Configurar usuário não-root
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

# Expor porta
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Comando padrão
CMD ["bundle", "exec", "ruby", "server.rb"]
