# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'

class ServiceClient
  attr_reader :base_url, :timeout

  def initialize(base_url, timeout = Config.timeouts[:http])
    @base_url = base_url
    @timeout = timeout
  end

  def get(endpoint, params = {})
    make_request(:get, endpoint, params)
  end

  def post(endpoint, data = {})
    make_request(:post, endpoint, data)
  end

  def put(endpoint, data = {})
    make_request(:put, endpoint, data)
  end

  def delete(endpoint)
    make_request(:delete, endpoint)
  end

  private

  def connection
    @connection ||= Faraday.new(
      url: base_url,
      headers: default_headers
    ) do |faraday|
      faraday.request :json
      faraday.request :retry, retry_options
      faraday.response :json
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = timeout
    end
  end

  def make_request(method, endpoint, data = {})
    AppLogger.info("Making #{method.upcase} request to #{base_url}#{endpoint}")

    response = case method
               when :get
                 connection.get(endpoint, data)
               when :post
                 connection.post(endpoint, data)
               when :put
                 connection.put(endpoint, data)
               when :delete
                 connection.delete(endpoint)
               end

    handle_response(response)
  rescue Faraday::TimeoutError => e
    AppLogger.error("Timeout error for #{base_url}#{endpoint}: #{e.message}")
    raise ServiceTimeoutError, "Service timeout: #{e.message}"
  rescue Faraday::ConnectionFailed => e
    AppLogger.error("Connection failed for #{base_url}#{endpoint}: #{e.message}")
    raise ServiceConnectionError, "Service connection failed: #{e.message}"
  rescue StandardError => e
    AppLogger.error("Unexpected error for #{base_url}#{endpoint}: #{e.message}")
    raise ServiceError, "Service error: #{e.message}"
  end

  def handle_response(response)
    case response.status
    when 200..299
      {
        success: true,
        data: response.body,
        status: response.status
      }
    when 400..499
      {
        success: false,
        error: response.body || 'Client error',
        status: response.status
      }
    when 500..599
      {
        success: false,
        error: response.body || 'Server error',
        status: response.status
      }
    else
      {
        success: false,
        error: 'Unknown error',
        status: response.status
      }
    end
  end

  def default_headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'User-Agent' => 'FiscalSystem/1.0'
    }
  end

  def retry_options
    {
      max: 3,
      interval: 0.5,
      interval_randomness: 0.5,
      backoff_factor: 2,
      exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
    }
  end
end

# Custom exceptions
class ServiceError < StandardError; end
class ServiceTimeoutError < ServiceError; end
class ServiceConnectionError < ServiceError; end
