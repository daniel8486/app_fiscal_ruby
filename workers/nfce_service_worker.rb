# frozen_string_literal: true

require 'sidekiq'

class NfceServiceWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, backtrace: true

  def perform(document_id)
    AppLogger.info('Sidekiq: Processando NFC-e', { document_id: document_id })
    document = Document[document_id]
    unless document
      AppLogger.error('Documento não encontrado', { document_id: document_id })
      return
    end
    service = NfceService.new
    result = service.process(document.to_hash)
    if result[:success]
      document.update_status('processed')
    else
      document.update_status('failed', result[:error])
    end
    AppLogger.info('Sidekiq: Fim do processamento NFC-e', { document_id: document_id, status: document.status })
  end
end
