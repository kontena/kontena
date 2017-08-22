class Certificate
  include Mongoid::Document
  include Mongoid::Timestamps

  field :domain, type: String
  field :valid_until, type: DateTime
  field :alt_names, type: Array

  field :cert_type, type: String

  # Need to have references to the secrets to know which ones to automatically update
  field :private_key, type: String
  field :certificate, type: String
  field :certificate_bundle, type: String

  # The secret prefix given by user in first request
  field :secret_prefix, type: String

  belongs_to :grid

  index({ 'domain' => 1 }, { unique: true })

end