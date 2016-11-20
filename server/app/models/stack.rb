class Stack
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String

  belongs_to :grid

  has_many :stack_revisions, dependent: :destroy
  has_many :stack_deploys, dependent: :destroy
  has_many :grid_services

  index({ grid_id: 1 })
  index({ name: 1 })

  validates_presence_of :name
  validates_uniqueness_of :name, scope: [:grid_id]

  # @return [String]
  def to_path
    "#{self.grid.try(:name)}/#{self.name}"
  end

  # @return [Symbol]
  def state
    services = self.grid_services.to_a
    return :initialized if services.all?{ |s| s.initialized? }
    return :deploying if services.any?{ |s| s.deploying? }
    return :stopped if services.all?{ |s| s.stopped? }
    return :running if services.all?{ |s| s.running? }

    :partially_running
  end

  # @return [StackRevision,NilClass]
  def latest_rev
    self.stack_revisions.order_by(revision: -1).first
  end

  # @param [GridService] grid_service
  def exposed_service?(grid_service)
    latest_rev = self.latest_rev
    return false unless latest_rev
    latest_rev.expose.to_s == grid_service.name
  end
end
