Sequel.migration do
  change do
    alter_table(:documents) do
      add_column :sefaz_response, :text
    end
  end
end
