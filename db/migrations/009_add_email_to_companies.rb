Sequel.migration do
  change do
    alter_table(:companies) do
      add_column :email, :text
    end
  end
end
