Sequel.migration do
  change do
    create_table(:process_logs) do
      primary_key :id
      Integer :document_id, null: false
      String :action, null: false
      String :status, null: false
      Text :message
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      foreign_key [:document_id], :documents
    end
  end
end
