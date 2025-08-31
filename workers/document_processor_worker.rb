# frozen_string_literal: true

require 'sidekiq'

class DocumentProcessorWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, backtrace: true

  def perform(document_id, _processing_options = {})
    AppLogger.info('Starting document processing worker', { document_id: document_id })

    start_time = Time.now

    begin
      # Busca o documento no banco
      document = Document[document_id]
      unless document
        AppLogger.error('Document not found', { document_id: document_id })
        return
      end

      # Atualiza status para processando
      document.update_status('processing')

      # Busca dados da empresa
      company = document.company
      unless company
        AppLogger.error('Company not found for document', { document_id: document_id })
        document.update_status('failed', 'Empresa não encontrada')
        return
      end

      # Prepara dados para processamento
      document_data = prepare_document_data(document, company)

      # Cria orquestrador e processa
      orchestrator = Orchestrator.new
      result = orchestrator.process_document(document_data)

      # Atualiza documento com resultado
      if result[:status] == 'completed'
        document.update_status('completed')
        document.add_sefaz_response(result[:data])

        # Log de sucesso
        ProcessLog.log_process(
          result[:process_id],
          'completed',
          document_id: document_id,
          message: 'Documento processado com sucesso',
          service_name: result[:data][:service],
          execution_time: Time.now - start_time
        )

        AppLogger.info('Document processed successfully', {
                         document_id: document_id,
                         process_id: result[:process_id],
                         execution_time: Time.now - start_time
                       })

      else
        document.update_status('failed', result[:data])

        # Log de erro
        ProcessLog.log_process(
          result[:process_id],
          'failed',
          document_id: document_id,
          message: result[:data],
          execution_time: Time.now - start_time,
          error_details: result[:data]
        )

        AppLogger.error('Document processing failed', {
                          document_id: document_id,
                          process_id: result[:process_id],
                          error: result[:data]
                        })
      end
    rescue StandardError => e
      # Log de erro crítico
      ProcessLog.log_process(
        SecureRandom.uuid,
        'error',
        document_id: document_id,
        message: "Worker error: #{e.message}",
        execution_time: Time.now - start_time,
        error_details: e.backtrace&.join("\n")
      )

      document&.update_status('failed', "Worker error: #{e.message}")

      AppLogger.error('Document processing worker error', {
                        document_id: document_id,
                        error: e.message,
                        backtrace: e.backtrace
                      })

      raise e # Re-levanta a exceção para o Sidekiq retry
    end
  end

  private

  def prepare_document_data(document, company)
    {
      id: document.id,
      type: document.document_type,
      company: {
        id: company.id,
        cnpj: company.cnpj,
        name: company.name,
        state_registration: company.state_registration,
        municipal_registration: company.municipal_registration,
        address: company.address,
        phone: company.phone,
        email: company.email,
        fiscal_regime: company.fiscal_regime,
        certificate_path: company.certificate_path
      },
      document: JSON.parse(document.document_data, symbolize_names: true)
    }
  end
end
