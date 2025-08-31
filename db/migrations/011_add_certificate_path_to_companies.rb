Sequel.migration do
  change do
    alter_table(:companies) do
      add_column :certificate_path, :text
    end
  end
end
