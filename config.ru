# frozen_string_literal: true

require_relative './app'
require 'sidekiq/web'

# Inicializa o Sidekiq
Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

# Painel web do Sidekiq protegido por autenticação básica
Sidekiq::Web.use Rack::Auth::Basic, 'Sidekiq' do |user, password|
  user == 'admin' && password == 'admin'
end

map '/sidekiq' do
  run Sidekiq::Web
end

run FiscalApp
