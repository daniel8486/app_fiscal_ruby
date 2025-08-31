Sequel.migration do
  change do
    add_column :companies, :active, TrueClass, default: true
  end
end
