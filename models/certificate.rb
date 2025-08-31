require 'sequel'

class Certificate < Sequel::Model
  many_to_one :company

  def validate
    super
    errors.add(:company_id, 'é obrigatório') unless company_id
    errors.add(:name, 'é obrigatório') if !name || name.empty?
    errors.add(:certificate_path, 'é obrigatório') if !certificate_path || certificate_path.empty?
    errors.add(:certificate_type, 'é obrigatório') if !certificate_type || certificate_type.empty?
  end

  def before_create
    super
    self.created_at = Time.now
    self.updated_at = Time.now
    self.active = true if active.nil?
  end

  def before_update
    super
    self.updated_at = Time.now
  end
end
