Sequel.migration do
  change do
    alter_table(:companies) do
      add_column :fiscal_regime, :text
    end
  end
end
