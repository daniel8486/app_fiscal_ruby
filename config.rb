# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'sinatra/base'
require 'sinatra/json'
require 'rack/cors'
require 'json'
require 'logger'
require 'faraday'
require 'sidekiq'
require 'redis'

# Autoload dos módulos
$LOAD_PATH.unshift(File.dirname(__FILE__))

require_relative 'lib/config'
require_relative 'lib/logger'
require_relative 'lib/redis_client'
require_relative 'lib/service_client'
require_relative 'lib/orchestrator'

require_relative 'models/document'
require_relative 'models/company'
require_relative 'models/process_log'

require_relative 'services/base_service'
require_relative 'services/nfe_service'
require_relative 'services/nfce_service'
require_relative 'services/nfse_service'
require_relative 'services/cte_service'
require_relative 'services/mdfe_service'
require_relative 'services/sat_service'

require_relative 'workers/document_processor_worker'
require_relative 'workers/notification_worker'

require_relative 'controllers/orchestrator_controller'
require_relative 'controllers/documents_controller'
require_relative 'controllers/health_controller'

require_relative 'app'
