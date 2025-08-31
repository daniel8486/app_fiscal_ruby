# frozen_string_literal: true

require 'logger'

class AppLogger
  class << self
    def logger
      @logger ||= begin
        logger = Logger.new($stdout)
        logger.level = Logger::INFO
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{progname}: #{msg}\n"
        end
        logger
      end
    end

    def info(message, context = {})
      log_with_context(:info, message, context)
    end

    def error(message, context = {})
      log_with_context(:error, message, context)
    end

    def warn(message, context = {})
      log_with_context(:warn, message, context)
    end

    def debug(message, context = {})
      log_with_context(:debug, message, context)
    end

    private

    def log_with_context(level, message, context)
      log_message = context.empty? ? message : "#{message} | Context: #{context.to_json}"
      logger.send(level, log_message)
    end
  end
end
