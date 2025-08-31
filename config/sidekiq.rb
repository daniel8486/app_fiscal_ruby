#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative '../config'

require 'sidekiq'
require 'sidekiq/web'

Sidekiq.configure_server do |config|
  config.redis = {
    url: Config.redis_url,
    network_timeout: 5,
    pool_timeout: 5
  }

  config.concurrency = ENV['SIDEKIQ_CONCURRENCY']&.to_i || 5

  config.queues = %w[critical high default low]
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: Config.redis_url,
    network_timeout: 5,
    pool_timeout: 5
  }
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    # Adicione middlewares personalizados aqui se necessário
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    # Adicione middlewares personalizados aqui se necessário
  end
end

Sidekiq.logger = AppLogger.logger
