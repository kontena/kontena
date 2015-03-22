class Image
  include Mongoid::Document
  include Mongoid::Timestamps

  field :image_id, type: String
  field :name, type: String
  field :size, type: Integer
  field :exposed_ports, type: Array, default: []
  field :virtual_size, type: Integer

  has_and_belongs_to_many :host_nodes
  has_many :grid_services

  index({ image_id: 1 })
  index({ name: 1 })
  index({ host_node_ids: 1 })
end
