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
  field :service_deploy_id, type: String

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

  def service_deploy_state
    if self.grid_service
      deploy = self.grid_service.grid_service_deploys.find_by(id: self.service_deploy_id)
      deploy.deploy_state
    else
      :not_linked
    end
  end
end