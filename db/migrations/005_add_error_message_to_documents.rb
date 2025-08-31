Sequel.migration do
  change do
    alter_table(:documents) do
      add_column :error_message, :text
    end
  end
end
