module ApiErrorHelper
  def self.format(errors, status: 400, code: nil)
    {
      success: false,
      error: 'Dados inválidos',
      details: Array(errors),
      code: code,
      status: status,
      timestamp: Time.now.iso8601
    }.compact
  end
end
