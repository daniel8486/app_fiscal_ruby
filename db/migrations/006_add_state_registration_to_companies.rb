Sequel.migration do
  change do
    alter_table(:companies) do
      add_column :state_registration, :text
    end
  end
end
