class Stack
  include Mongoid::Document
  include Mongoid::Timestamps

  NULL_STACK = 'null'.freeze

  field :name, type: String
  field :parent_name, type: String

  belongs_to :grid

  has_many :stack_revisions, dependent: :destroy
  has_many :stack_deploys, dependent: :destroy
  has_many :grid_services

  index({ grid_id: 1 })
  index({ name: 1 })
  index({ parent_name: 1 })

  validates_presence_of :name
  validates_uniqueness_of :name, scope: [:grid_id]

  validate :parent_name_is_not_same_as_name

  def parent_name_is_not_same_as_name
    if parent_name && name && parent_name == name
      errors.add(:parent_name, "Parent name can't be the same as name")
    end
  end

  def has_parent?
    !parent_name.nil?
  end

  def top_parent
    return self unless has_parent?
    parent.top_parent
  end

  def parent
    return nil unless has_parent?
    self.class.where(grid_id: grid_id, name: parent_name).first
  end

  def children
    self.class.where(grid_id: grid_id, parent_name: name)
  end

  def parent_chain
    return [] unless has_parent?
    [parent] + parent.parent_chain
  end

  # @return [String]
  def to_path
    "#{self.grid.try(:name)}/#{self.name}"
  end

  # @return [String]
  def domain
    if self.name == NULL_STACK
      self.grid.domain
    else
      "#{self.name}.#{self.grid.domain}"
    end
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
