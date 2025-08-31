require 'sinatra/base'
require_relative '../models/certificate'
require_relative '../models/company'

class CertificatesController < Sinatra::Base
  post '/api/v1/certificates' do
    data = JSON.parse(request.body.read)
    require_relative '../helpers/api_error_helper'
    certificate = Certificate.new(
      company_id: data['company_id'],
      name: data['name'],
      certificate_path: data['certificate_path'],
      certificate_type: data['certificate_type'],
      valid_until: data['valid_until'],
      active: data['active']
    )
    if certificate.valid?
      certificate.save
      status 201
      {
        success: true,
        data: certificate.values
      }.to_json
    else
      status 400
      ApiErrorHelper.format(certificate.errors.full_messages, status: 400).to_json
    end
  end

  get '/api/v1/certificates/:id' do
    certificate = Certificate[params[:id]]
    if certificate
      {
        success: true,
        data: certificate.values
      }.to_json
    else
      status 404
      {
        success: false,
        error: 'Certificado não encontrado'
      }.to_json
    end
  end

  get '/api/v1/certificates' do
    certificates = Certificate.all
    {
      success: true,
      data: certificates.map(&:values)
    }.to_json
  end
end
