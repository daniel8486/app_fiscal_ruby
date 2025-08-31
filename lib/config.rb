# frozen_string_literal: true

class Config
  class << self
    def database_url
      ENV['DATABASE_URL'] || 'postgresql://localhost:5432/fiscal_system'
    end

    def redis_url
      ENV['REDIS_URL'] || 'redis://localhost:6379/0'
    end

    def environment
      ENV['ENVIRONMENT'] || 'development'
    end

    def log_level
      ENV['LOG_LEVEL']&.to_sym || :info
    end

    def orchestrator_port
      ENV['ORCHESTRATOR_PORT']&.to_i || 4000
    end

    def service_ports
      {
        nfe: ENV['NFE_SERVICE_PORT']&.to_i || 4001,
        nfce: ENV['NFCE_SERVICE_PORT']&.to_i || 4002,
        nfse: ENV['NFSE_SERVICE_PORT']&.to_i || 4003,
        cte: ENV['CTE_SERVICE_PORT']&.to_i || 4004,
        mdfe: ENV['MDFE_SERVICE_PORT']&.to_i || 4005,
        sat: ENV['SAT_SERVICE_PORT']&.to_i || 4006
      }
    end

    def service_urls
      {
        nfe: ENV['NFE_SERVICE_URL'] || "http://localhost:#{service_ports[:nfe]}",
        nfce: ENV['NFCE_SERVICE_URL'] || "http://localhost:#{service_ports[:nfce]}",
        nfse: ENV['NFSE_SERVICE_URL'] || "http://localhost:#{service_ports[:nfse]}",
        cte: ENV['CTE_SERVICE_URL'] || "http://localhost:#{service_ports[:cte]}",
        mdfe: ENV['MDFE_SERVICE_URL'] || "http://localhost:#{service_ports[:mdfe]}",
        sat: ENV['SAT_SERVICE_URL'] || "http://localhost:#{service_ports[:sat]}"
      }
    end

    def timeouts
      {
        http: ENV['HTTP_TIMEOUT']&.to_i || 30,
        service: ENV['SERVICE_TIMEOUT']&.to_i || 60
      }
    end

    def sefaz_config
      {
        environment: ENV['SEFAZ_ENVIRONMENT'] || 'homologacao',
        certificate_path: ENV['SEFAZ_CERTIFICATE_PATH'] || './certificates/',
        certificate_password: ENV['SEFAZ_CERTIFICATE_PASSWORD']
      }
    end

    def security_config
      {
        api_secret_key: ENV['API_SECRET_KEY'],
        jwt_secret: ENV['JWT_SECRET']
      }
    end
  end
end
