# frozen_string_literal: true

class ProcessLog < Sequel::Model
  many_to_one :document

  dataset_module do
    def by_process_id(process_id)
      where(process_id: process_id)
    end

    def by_status(status)
      where(status: status)
    end

    def recent(hours = 24)
      where(created_at: (Time.now - (hours * 3600))..Time.now)
    end
  end

  def validate
    super
    errors.add(:process_id, 'não pode estar vazio') if !process_id || process_id.empty?
    errors.add(:status, 'não pode estar vazio') if !status || status.empty?
  end

  def before_create
    super
    self.created_at = Time.now
  end

  def to_hash
    {
      id: id,
      process_id: process_id,
      document_id: document_id,
      status: status,
      message: message,
      service_name: service_name,
      execution_time: execution_time,
      error_details: error_details,
      created_at: created_at
    }
  end

  def self.log_process(process_id, status, options = {})
    create(
      process_id: process_id,
      status: status,
      document_id: options[:document_id],
      message: options[:message],
      service_name: options[:service_name],
      execution_time: options[:execution_time],
      error_details: options[:error_details]
    )
  end

  def self.get_process_history(process_id)
    by_process_id(process_id).order(:created_at).all
  end
end

# Schema para criar a tabela se não existir
unless DB.table_exists?(:process_logs)
  DB.create_table :process_logs do
    primary_key :id
    String :process_id, null: false
    Integer :document_id
    String :status, null: false
    Text :message
    String :service_name
    Float :execution_time
    Text :error_details
    DateTime :created_at

    index :process_id
    index :status
    index :document_id
    index :created_at
  end
end
