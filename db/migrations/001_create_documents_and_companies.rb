Sequel.migration do
  change do
    create_table(:companies) do
      primary_key :id
      String :cnpj, null: false, unique: true
      String :name
      String :address
      TrueClass :active, default: true
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:documents) do
      primary_key :id
      String :document_type, null: false
      Integer :company_id, null: false
      String :status, null: false, default: 'draft'
      Text :document_data, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
      foreign_key [:company_id], :companies
    end
  end
end
