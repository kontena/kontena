class GridDomainAuthorization
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  belongs_to :grid

  enum :state, [:created, :requested, :validated], default: :created
  field :domain, type: String
  field :challenge, type: Hash
  field :challenge_opts, type: Hash # TODO encrypt?

  index({ grid_id: 1 })
  index({ domain: 1 })
  index({ grid_id: 1, domain: 1 }, {unique: true})

  validates_uniqueness_of :domain, scope: [:grid_id]

  # @return [String]
  def to_path
    "#{self.grid.try(:name)}/#{self.name}"
  end
end