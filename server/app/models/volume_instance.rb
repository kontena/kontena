class VolumeInstance
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String

  belongs_to :host_node

  belongs_to :volume

  validates_uniqueness_of :name, scope: [:host_node]

  index({ host_node_id: 1 })
  index({ volume_id: 1 })
end
