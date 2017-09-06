require 'symmetric-encryption'

class GridDomainAuthorization
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  belongs_to :grid

  enum :state, [:created, :requested, :validated, :error], default: :created

  field :domain, type: String
  field :challenge, type: Hash
  field :challenge_opts, type: Hash # TODO encrypt?
  field :authorization_type, type: String, default: 'tls-sni-01'

  belongs_to :grid_service_deploy

  field :encrypted_tls_sni_certificate, type: String, encrypted: true

  belongs_to :grid_service # Usually a LB service

  index({ grid_id: 1 })
  index({ domain: 1 })
  index({ grid_id: 1, domain: 1 }, {unique: true})

  validates_uniqueness_of :domain, scope: [:grid_id]

  # @return [String]
  def to_path
    "#{self.grid.try(:name)}/#{self.domain}"
  end

  def status
    if self.grid_service_deploy && !self.grid_service_deploy.finished?
      # Deploy still in progress
      :deploying # So that CLI or other clients know to wait before requesting the cert
    elsif self.grid_service_deploy && self.grid_service_deploy.finished? && self.grid_service_deploy.error?
      :deploy_error
    else
      self.state
    end
  end

end