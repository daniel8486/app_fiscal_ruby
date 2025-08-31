Sequel.migration do
  change do
    create_table(:certificates) do
      primary_key :id
      foreign_key :company_id, :companies, null: false
      String :name, null: false
      Text :certificate_path, null: false
      String :certificate_type, null: false # ex: 'A1', 'A3', 'producao', 'homologacao'
      Date :valid_until
      Boolean :active, default: true
      DateTime :created_at
      DateTime :updated_at
      index :company_id
      index :active
    end
  end
end
