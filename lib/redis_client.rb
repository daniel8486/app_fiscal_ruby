# frozen_string_literal: true

require 'redis'

class RedisClient
  class << self
    def client
      @client ||= Redis.new(url: Config.redis_url)
    end

    def set_with_expiry(key, value, expiry_seconds = 3600)
      client.setex(key, expiry_seconds, value.to_json)
    end

    def get(key)
      value = client.get(key)
      value ? JSON.parse(value) : nil
    rescue JSON::ParserError
      value
    end

    def delete(key)
      client.del(key)
    end

    def exists?(key)
      client.exists?(key)
    end

    def publish(channel, message)
      client.publish(channel, message.to_json)
    end

    def subscribe(channel, &block)
      client.subscribe(channel) do |on|
        on.message do |channel, message|
          parsed_message = JSON.parse(message)
          block.call(channel, parsed_message)
        end
      end
    end

    # Queue operations for job processing
    def push_to_queue(queue_name, job_data)
      client.lpush("queue:#{queue_name}", job_data.to_json)
    end

    def pop_from_queue(queue_name, timeout = 0)
      result = client.brpop("queue:#{queue_name}", timeout)
      result ? JSON.parse(result[1]) : nil
    rescue JSON::ParserError
      result[1] if result
    end

    def queue_size(queue_name)
      client.llen("queue:#{queue_name}")
    end
  end
end
