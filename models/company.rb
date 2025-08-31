# frozen_string_literal: true

class Company < Sequel::Model
  one_to_many :documents

  dataset_module do
    def active
      where(active: true)
    end

    def by_cnpj(cnpj)
      where(cnpj: cnpj)
    end
  end

  def validate
    super
    errors.add(:name, 'não pode estar vazio') if !name || name.empty?
    errors.add(:cnpj, 'não pode estar vazio') if !cnpj || cnpj.empty?
    errors.add(:cnpj, 'formato inválido') unless valid_cnpj?
  end

  def before_create
    super
    self.created_at = Time.now
    self.updated_at = Time.now
    self.active = true unless active == false
  end

  def before_update
    super
    self.updated_at = Time.now
  end

  def to_hash
    {
      id: id,
      name: name,
      cnpj: cnpj,
      state_registration: state_registration,
      municipal_registration: municipal_registration,
      address: address,
      phone: phone,
      email: email,
      fiscal_regime: fiscal_regime,
      certificate_path: certificate_path,
      active: active,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def formatted_cnpj
    return cnpj unless cnpj

    cnpj.gsub(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '\1.\2.\3/\4-\5')
  end

  private

  def valid_cnpj?
    return false unless cnpj

    # Remove formatação
    clean_cnpj = cnpj.gsub(/\D/, '')
    return false unless clean_cnpj.length == 14

    # Validação básica (sequência não pode ser toda igual)
    return false if clean_cnpj.chars.uniq.length == 1

    # Aqui você pode implementar o algoritmo completo de validação do CNPJ
    true
  end
end

# Schema para criar a tabela se não existir
unless DB.table_exists?(:companies)
  DB.create_table :companies do
    primary_key :id
    String :name, null: false
    String :cnpj, null: false, unique: true
    String :state_registration
    String :municipal_registration
    Text :address
    String :phone
    String :email
    String :fiscal_regime
    String :certificate_path
    Boolean :active, default: true
    DateTime :created_at
    DateTime :updated_at

    index :cnpj
    index :active
  end
end
