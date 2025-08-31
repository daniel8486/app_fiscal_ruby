# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.3.8'

# Framework web
gem 'puma', '~> 6.0'
gem 'sinatra', '~> 3.0'
gem 'sinatra-contrib', '~> 3.0'

# JSON handling
gem 'json', '~> 2.6'
gem 'prometheus-client'

# HTTP client
gem 'faraday', '~> 2.0'
gem 'faraday-retry', '~> 2.0'

# Background jobs e mensageria
gem 'redis', '~> 5.0'
gem 'sidekiq', '~> 7.0'

# Database
gem 'pg', '~> 1.4'
gem 'sequel', '~> 5.68'

# Configuration
gem 'dotenv', '~> 2.8'

# Logging
gem 'semantic_logger', '~> 4.12'

# XML handling para documentos fiscais
gem 'builder', '~> 3.2'
gem 'nokogiri', '~> 1.14'

# Validation
gem 'dry-schema', '~> 1.13'
gem 'dry-validation', '~> 1.10'

# CORS
gem 'rack-cors', '~> 2.0'

group :development, :test do
  gem 'factory_bot', '~> 6.2'
  gem 'faker', '~> 3.2'
  gem 'rspec', '~> 3.12'
  gem 'rubocop', '~> 1.50'
  gem 'rubocop-rspec', '~> 2.20'
end

group :development do
  gem 'rerun', '~> 0.14'
end
