#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config'

DB = Sequel.connect(Config.database_url)

DB.logger = AppLogger.logger if Config.environment != 'production'

DB.extension :connection_validator
DB.pool.connection_validation_timeout = 3600

DB.extension :pg_json
DB.extension :pg_array

DB.timezone = :utc

Sequel::Migrator.check_current(DB, 'db/migrations') if defined?(Sequel::Migrator)
