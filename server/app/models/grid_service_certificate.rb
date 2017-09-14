class GridServiceCertificate
  include Mongoid::Document

  field :subject, type: String # To identify the cert object
  field :name, type: String, default: 'SSL_CERTS'
  field :type, type: String, default: 'env' # For future use where we could expose certs as files

  embedded_in :grid_service
end
