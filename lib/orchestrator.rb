# frozen_string_literal: true

require 'securerandom'

class Orchestrator
  attr_reader :process_id

  def initialize
    @process_id = SecureRandom.uuid
    @services = initialize_services
  end

  def process_document(document_data)
    AppLogger.info('Starting document processing', { process_id: @process_id, document_type: document_data[:type] })

    # Salva o status inicial no Redis
    save_process_status('started', { document_data: document_data })

    begin
      # Valida os dados do documento
      validation_result = validate_document(document_data)
      unless validation_result[:valid]
        save_process_status('failed', { error: validation_result[:errors] })
        return process_result('failed', validation_result[:errors])
      end

      # Determina qual serviço usar baseado no tipo de documento
      service = get_service_for_document(document_data[:type])
      unless service
        error_msg = "Serviço não encontrado para o tipo de documento: #{document_data[:type]}"
        save_process_status('failed', { error: error_msg })
        return process_result('failed', error_msg)
      end

      save_process_status('processing', { service: service.class.name })

      # Processa o documento no serviço específico
      processing_result = service.process(document_data)

      if processing_result[:success]
        save_process_status('completed', processing_result)

        # Envia notificação assíncrona
        NotificationWorker.perform_async(@process_id, 'document_processed', processing_result)

        process_result('completed', processing_result)
      else
        save_process_status('failed', processing_result)
        process_result('failed', processing_result[:error])
      end
    rescue StandardError => e
      AppLogger.error('Error processing document', { process_id: @process_id, error: e.message })
      save_process_status('failed', { error: e.message, backtrace: e.backtrace })
      process_result('failed', e.message)
    end
  end

  def get_process_status
    RedisClient.get("process:#{@process_id}")
  end

  def self.get_process_status(process_id)
    RedisClient.get("process:#{process_id}")
  end

  private

  def initialize_services
    {
      'nfe' => NfeService.new,
      'nfce' => NfceService.new,
      'nfse' => NfseService.new,
      'cte' => CteService.new,
      'mdfe' => MdfeService.new,
      'sat' => SatService.new
    }
  end

  def validate_document(document_data)
    errors = []

    errors << 'Tipo de documento é obrigatório' if document_data[:type].nil? || document_data[:type].empty?
    errors << 'Dados da empresa são obrigatórios' if document_data[:company].nil?
    errors << 'Dados do documento são obrigatórios' if document_data[:document].nil?

    if document_data[:type] && !@services.key?(document_data[:type].downcase)
      errors << "Tipo de documento não suportado: #{document_data[:type]}"
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  def get_service_for_document(document_type)
    @services[document_type.downcase]
  end

  def save_process_status(status, data = {})
    status_data = {
      process_id: @process_id,
      status: status,
      timestamp: Time.now.iso8601,
      data: data
    }

    RedisClient.set_with_expiry("process:#{@process_id}", status_data, 86_400) # 24 horas

    # Publica notificação de mudança de status
    RedisClient.publish('process_status_updates', status_data)
  end

  def process_result(status, data)
    {
      process_id: @process_id,
      status: status,
      data: data,
      timestamp: Time.now.iso8601
    }
  end
end
