# frozen_string_literal: true

class BaseService
  attr_reader :service_name, :client

  def initialize(service_name, service_url)
    @service_name = service_name
    @client = ServiceClient.new(service_url)
  end

  def process(document_data)
    start_time = Time.now

    begin
      AppLogger.info("Processing #{service_name} document", {
                       document_id: document_data[:id],
                       company_id: document_data[:company][:id]
                     })

      # Validação específica do serviço
      validation_result = validate_document_data(document_data)
      unless validation_result[:valid]
        return {
          success: false,
          error: validation_result[:errors],
          service: service_name
        }
      end

      # Processamento específico do documento
      processing_result = process_document(document_data)

      # Log do tempo de execução
      execution_time = Time.now - start_time

      if processing_result[:success]
        AppLogger.info("#{service_name} processing completed successfully", {
                         document_id: document_data[:id],
                         execution_time: execution_time
                       })

      else
        AppLogger.error("#{service_name} processing failed", {
                          document_id: document_data[:id],
                          error: processing_result[:error],
                          execution_time: execution_time
                        })

      end
      processing_result.merge({
                                service: service_name,
                                execution_time: execution_time
                              })
    rescue StandardError => e
      execution_time = Time.now - start_time
      AppLogger.error("#{service_name} service error", {
                        document_id: document_data[:id],
                        error: e.message,
                        execution_time: execution_time
                      })

      {
        success: false,
        error: "Service error: #{e.message}",
        service: service_name,
        execution_time: execution_time
      }
    end
  end

  def health_check
    response = client.get('/health')
    {
      service: service_name,
      status: response[:success] ? 'healthy' : 'unhealthy',
      response_time: measure_response_time { client.get('/health') },
      timestamp: Time.now.iso8601
    }
  rescue StandardError => e
    {
      service: service_name,
      status: 'error',
      error: e.message,
      timestamp: Time.now.iso8601
    }
  end

  protected

  # Métodos que devem ser implementados pelas classes filhas
  def validate_document_data(document_data)
    raise NotImplementedError, "validate_document_data must be implemented by #{self.class}"
  end

  def process_document(document_data)
    raise NotImplementedError, "process_document must be implemented by #{self.class}"
  end

  private

  def measure_response_time
    start_time = Time.now
    yield
    Time.now - start_time
  end

  def format_error_response(error_message)
    {
      success: false,
      error: error_message,
      service: service_name,
      timestamp: Time.now.iso8601
    }
  end

  def format_success_response(data)
    {
      success: true,
      data: data,
      service: service_name,
      timestamp: Time.now.iso8601
    }
  end
end
