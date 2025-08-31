# frozen_string_literal: true

require 'sequel'

# Configuração do banco de dados
DB = Sequel.connect(Config.database_url)

class Document < Sequel::Model
  many_to_one :company
  one_to_many :process_logs

  dataset_module do
    def by_type(type)
      where(document_type: type)
    end

    def by_status(status)
      where(status: status)
    end

    def recent(days = 30)
      where(created_at: (Date.today - days)..Date.today)
    end
  end

  def validate
    super
    errors.add(:document_type, 'não pode estar vazio') if !document_type || document_type.empty?
    errors.add(:company_id, 'é obrigatório') unless company_id
    errors.add(:document_data, 'não pode estar vazio') if !document_data || document_data.empty?
  end

  def before_create
    super
    self.created_at = Time.now
    self.updated_at = Time.now
    self.status = 'pending' unless status
    self.sefaz_response = nil unless sefaz_response
  end

  def before_update
    super
    self.updated_at = Time.now
  end

  def to_hash
    {
      id: id,
      document_type: document_type,
      status: status,
      document_data: document_data,
      sefaz_response: sefaz_response || nil,
      error_message: error_message,
      company_id: company_id,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def update_status(new_status, message = nil)
    update(
      status: new_status,
      error_message: message,
      updated_at: Time.now
    )
  end

  def add_sefaz_response(response_data)
    update(
      sefaz_response: response_data,
      updated_at: Time.now
    )
  end
end

# Schema para criar a tabela se não existir
unless DB.table_exists?(:documents)
  DB.create_table :documents do
    primary_key :id
    String :document_type, null: false
    String :status, default: 'pending'
    Text :document_data, null: false
    Text :sefaz_response
    Text :error_message
    Integer :company_id, null: false
    DateTime :created_at
    DateTime :updated_at

    index :document_type
    index :status
    index :company_id
    index :created_at
  end
end
