class Configuration
  include Mongoid::Document

  field :subject, type: String
  field :valid_until, type: DateTime
  field :domains, type: Array

  field :cert_type, type: String

  has_one :private_key, class_name: 'GridSecret'
  has_one :certificate, class_name: 'GridSecret'
  has_one :certificate_bundle, class_name: 'GridSecret'

  belongs_to :grid

  index({ 'subject' => 1 }, { unique: true })

end