#!/bin/bash


echo "Limpando arquivos temporários e processos duplicados..."

if docker compose -f docker-compose.monitoring.yml ps | grep sidekiq; then
  docker compose -f docker-compose.monitoring.yml stop sidekiq
fi
if docker compose -f docker-compose.monitoring.yml ps | grep prometheus; then
  docker compose -f docker-compose.monitoring.yml stop prometheus
fi
if docker compose -f docker-compose.monitoring.yml ps | grep grafana; then
  docker compose -f docker-compose.monitoring.yml stop grafana
fi
if docker compose -f docker-compose.monitoring.yml ps | grep redis; then
  docker compose -f docker-compose.monitoring.yml stop redis
fi

pkill -f sidekiq || true
pkill -f puma || true
pkill -f ruby || true

rm -rf tmp/*
rm -rf vendor/bundle

echo "Reiniciando containers Docker..."
docker compose -f docker-compose.monitoring.yml up -d

echo "Ambiente limpo e reiniciado!"
