class Certificate
  include Mongoid::Document

  field :domain, type: String
  field :valid_until, type: DateTime
  field :alt_names, type: Array

  field :cert_type, type: String

  # Need to have references to the secrets to know which ones to automatically update
  field :private_key, type: String
  field :certificate, type: String
  field :certificate_bundle, type: String

  belongs_to :grid

  index({ 'domain' => 1 }, { unique: true })

  def to_path
    "#{self.grid.name}/#{self.domain}"
  end

end