require 'securerandom'

module RequestIdHelper
  def self.generate
    SecureRandom.uuid
  end
end
