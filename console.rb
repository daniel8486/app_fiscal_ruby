#!/usr/bin/env ruby
# frozen_string_literal: true

# Console interativo para desenvolvimento
require_relative 'config'

puts 'Console Fiscal System'
puts '========================'
puts 'Estatísticas:'
puts "• Empresas: #{Company.count}"
puts "• Documentos: #{Document.count}"
puts "• Logs: #{ProcessLog.count}"
puts ''
puts 'Exemplos de uso:'
puts 'Company.all'
puts 'Document.recent'
puts "ProcessLog.by_status('completed')"
puts ''

require 'irb'
IRB.start
