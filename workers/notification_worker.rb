# frozen_string_literal: true

require 'sidekiq'

class NotificationWorker
  include Sidekiq::Worker

  sidekiq_options retry: 2, backtrace: true

  def perform(process_id, event_type, data = {})
    AppLogger.info('Sending notification', {
                     process_id: process_id,
                     event_type: event_type
                   })

    begin
      case event_type
      when 'document_processed'
        send_document_processed_notification(process_id, data)
      when 'document_failed'
        send_document_failed_notification(process_id, data)
      when 'status_update'
        send_status_update_notification(process_id, data)
      else
        AppLogger.warn('Unknown notification event type', {
                         process_id: process_id,
                         event_type: event_type
                       })
      end
    rescue StandardError => e
      AppLogger.error('Notification error', {
                        process_id: process_id,
                        event_type: event_type,
                        error: e.message
                      })

      raise e # Re-levanta para retry do Sidekiq
    end
  end

  private

  def send_document_processed_notification(process_id, data)
    # Implementar envio de notificação por email/webhook/etc
    notification_data = {
      process_id: process_id,
      event: 'document_processed',
      status: 'success',
      message: 'Documento fiscal processado com sucesso',
      data: data,
      timestamp: Time.now.iso8601
    }

    # Publica notificação no Redis para clientes em tempo real
    RedisClient.publish('notifications', notification_data)

    # Enviar email se configurado
    send_email_notification(notification_data) if email_enabled?

    # Enviar webhook se configurado
    send_webhook_notification(notification_data) if webhook_enabled?

    AppLogger.info('Document processed notification sent', { process_id: process_id })
  end

  def send_document_failed_notification(process_id, data)
    notification_data = {
      process_id: process_id,
      event: 'document_failed',
      status: 'error',
      message: 'Falha no processamento do documento fiscal',
      error: data[:error],
      timestamp: Time.now.iso8601
    }

    # Publica notificação no Redis
    RedisClient.publish('notifications', notification_data)

    # Enviar notificação de erro prioritária
    send_error_notification(notification_data) if error_notifications_enabled?

    AppLogger.info('Document failed notification sent', { process_id: process_id })
  end

  def send_status_update_notification(process_id, data)
    notification_data = {
      process_id: process_id,
      event: 'status_update',
      status: data[:status],
      message: data[:message] || 'Status do processamento atualizado',
      timestamp: Time.now.iso8601
    }

    # Publica atualização de status no Redis
    RedisClient.publish('status_updates', notification_data)

    AppLogger.debug('Status update notification sent', { process_id: process_id })
  end

  def send_email_notification(notification_data)
    # Implementar envio de email usando um provedor (SendGrid, SES, etc.)
    AppLogger.info('Email notification would be sent', {
                     process_id: notification_data[:process_id]
                   })
  end

  def send_webhook_notification(notification_data)
    # Implementar envio de webhook para sistemas externos
    webhook_url = ENV['NOTIFICATION_WEBHOOK_URL']
    return unless webhook_url

    begin
      client = ServiceClient.new(webhook_url)
      response = client.post('', notification_data)

      if response[:success]
        AppLogger.info('Webhook notification sent successfully', {
                         process_id: notification_data[:process_id],
                         webhook_url: webhook_url
                       })
      else
        AppLogger.error('Webhook notification failed', {
                          process_id: notification_data[:process_id],
                          webhook_url: webhook_url,
                          error: response[:error]
                        })
      end
    rescue StandardError => e
      AppLogger.error('Webhook notification error', {
                        process_id: notification_data[:process_id],
                        error: e.message
                      })
    end
  end

  def send_error_notification(notification_data)
    # Implementar notificação específica para erros (Slack, PagerDuty, etc.)
    AppLogger.warn('Error notification would be sent', {
                     process_id: notification_data[:process_id]
                   })
  end

  def email_enabled?
    ENV['EMAIL_NOTIFICATIONS_ENABLED'] == 'true'
  end

  def webhook_enabled?
    !ENV['NOTIFICATION_WEBHOOK_URL'].nil? && !ENV['NOTIFICATION_WEBHOOK_URL'].empty?
  end

  def error_notifications_enabled?
    ENV['ERROR_NOTIFICATIONS_ENABLED'] == 'true'
  end
end
