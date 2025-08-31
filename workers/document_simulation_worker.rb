require_relative File.join(__dir__, 'nfe_service_worker')
require_relative File.join(__dir__, 'cte_service_worker')
require_relative File.join(__dir__, 'mdfe_service_worker')
require_relative File.join(__dir__, 'sat_service_worker')
require_relative File.join(__dir__, 'nfce_service_worker')
require_relative File.join(__dir__, 'nfse_service_worker')

require 'sidekiq'

class DocumentSimulationWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, backtrace: true

  def perform(document_type, company_id)
    # Simula envio de documento fiscal
    document = Document.create(
      document_type: document_type,
      document_data: { numero: rand(1000..9999), valor: rand(100..1000) }.to_json,
      company_id: company_id,
      status: 'draft'
    )
    # Enfileira processamento real
    case document_type
    when 'nfe'
      NfeServiceWorker.perform_async(document.id)
    when 'cte'
      CteServiceWorker.perform_async(document.id)
    when 'mdfe'
      MdfeServiceWorker.perform_async(document.id)
    when 'sat'
      SatServiceWorker.perform_async(document.id)
    when 'nfce'
      NfceServiceWorker.perform_async(document.id)
    when 'nfse'
      NfseServiceWorker.perform_async(document.id)
    end
    AppLogger.info('Simulação de envio enfileirada', { document_id: document.id, type: document_type })
  end
end
