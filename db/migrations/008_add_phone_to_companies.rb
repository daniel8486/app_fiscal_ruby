Sequel.migration do
  change do
    alter_table(:companies) do
      add_column :phone, :text
    end
  end
end
