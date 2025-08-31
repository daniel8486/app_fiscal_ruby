# frozen_string_literal: true

class HealthController
  def status
    health_data = {
      status: 'healthy',
      timestamp: Time.now.iso8601,
      version: '1.0.0',
      services: check_services_health,
      dependencies: check_dependencies_health
    }

    overall_status = calculate_overall_status(health_data)

    {
      status: overall_status == 'healthy' ? 200 : 503,
      body: health_data.merge(status: overall_status).to_json
    }
  rescue StandardError => e
    AppLogger.error('Health check error', { error: e.message })

    {
      status: 503,
      body: {
        status: 'unhealthy',
        error: e.message,
        timestamp: Time.now.iso8601
      }.to_json
    }
  end

  private

  def check_services_health
    services = {}

    # Verifica cada serviço fiscal
    Config.service_urls.each do |service_name, url|
      client = ServiceClient.new(url, 5) # timeout de 5 segundos
      start_time = Time.now
      response = client.get('/health')
      response_time = Time.now - start_time

      services[service_name] = {
        status: response[:success] ? 'healthy' : 'unhealthy',
        response_time_ms: (response_time * 1000).round(2),
        url: url,
        last_check: Time.now.iso8601
      }

      services[service_name].merge!(response[:data]) if response[:data]
    rescue StandardError => e
      services[service_name] = {
        status: 'error',
        error: e.message,
        url: url,
        last_check: Time.now.iso8601
      }
    end

    services
  end

  def check_dependencies_health
    dependencies = {}

    # Verifica Redis
    dependencies[:redis] = check_redis_health

    # Verifica PostgreSQL
    dependencies[:postgresql] = check_postgresql_health

    # Verifica Sidekiq
    dependencies[:sidekiq] = check_sidekiq_health

    dependencies
  end

  def check_redis_health
    start_time = Time.now
    RedisClient.client.ping
    response_time = Time.now - start_time

    info = RedisClient.client.info

    {
      status: 'healthy',
      response_time_ms: (response_time * 1000).round(2),
      version: info['redis_version'],
      memory_usage: info['used_memory_human'],
      connected_clients: info['connected_clients'],
      last_check: Time.now.iso8601
    }
  rescue StandardError => e
    {
      status: 'error',
      error: e.message,
      last_check: Time.now.iso8601
    }
  end

  def check_postgresql_health
    start_time = Time.now
    DB.fetch('SELECT 1').first
    response_time = Time.now - start_time

    version = DB.fetch('SELECT version()').first[:version]

    {
      status: 'healthy',
      response_time_ms: (response_time * 1000).round(2),
      version: version.split(' ').first(2).join(' '),
      last_check: Time.now.iso8601
    }
  rescue StandardError => e
    {
      status: 'error',
      error: e.message,
      last_check: Time.now.iso8601
    }
  end

  def check_sidekiq_health
    require 'sidekiq/api'

    stats = Sidekiq::Stats.new

    {
      status: 'healthy',
      processed: stats.processed,
      failed: stats.failed,
      busy: stats.workers_size,
      enqueued: stats.enqueued,
      scheduled: stats.scheduled_size,
      retries: stats.retry_size,
      dead: stats.dead_size,
      last_check: Time.now.iso8601
    }
  rescue StandardError => e
    {
      status: 'error',
      error: e.message,
      last_check: Time.now.iso8601
    }
  end

  def calculate_overall_status(health_data)
    # Verifica se algum serviço crítico está com problema
    critical_services = %i[redis postgresql]

    critical_services.each do |service|
      return 'unhealthy' if health_data[:dependencies][service][:status] != 'healthy'
    end

    # Verifica se mais da metade dos serviços fiscais estão com problema
    fiscal_services = health_data[:services]
    total_services = fiscal_services.count
    unhealthy_services = fiscal_services.count { |_, data| data[:status] != 'healthy' }

    return 'degraded' if total_services.positive? && (unhealthy_services.to_f / total_services) > 0.5

    'healthy'
  end
end
