class Stack
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  field :name, type: String
  field :version, type: String, default: '1'

  belongs_to :grid

  has_many :stack_revisions, dependent: :destroy
  has_many :grid_services

  index({ grid_id: 1 })
  index({ name: 1 })

  validates_presence_of :name
  validates_uniqueness_of :name, scope: [:grid_id]

  # @return [String]
  def to_path
    "#{self.grid.try(:name)}/#{self.name}"
  end

  def increase_version
    self.set(version: (self.version.to_i + 1))
    self.version
  end

  def state
    return :initialized if self.grid_services.all?{ |s| s.initialized? }
    return :deploying if self.grid_services.any?{ |s| s.deploying? }
    return :stopped if self.grid_services.all?{ |s| s.stopped? }
    return :running if self.grid_services.all?{ |s| s.running? }

    :partially_running
  end
end
