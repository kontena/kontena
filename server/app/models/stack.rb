class Stack
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  field :name, type: String
  field :version, type: String, default: '1'
  enum :state, [:initialized, :deployed, :terminated]

  belongs_to :grid

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

end