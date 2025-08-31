#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config'

# Executa a aplicação
if $PROGRAM_NAME == __FILE__
  FiscalApp.run!(
    host: '0.0.0.0',
    port: Config.orchestrator_port,
    server: 'puma'
  )
end
