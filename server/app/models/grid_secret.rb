class GridSecret
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :grid

  field :name, type: String
  field :value, type: String

  validates_presence_of :name, :value
  validates_uniqueness_of :name, scope: [:grid_id]

  index({ grid_id: 1 })

  # @return [String]
  def to_path
    "#{self.grid.try(:name)}/#{self.name}"
  end
end