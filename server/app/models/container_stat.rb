class ContainerStat
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :spec, type: Hash
  field :cpu, type: Hash
  field :memory, type: Hash
  field :filesystem, type: Array
  field :diskio, type: Hash
  field :network, type: Hash

  belongs_to :grid
  belongs_to :grid_service
  belongs_to :container

  index({ grid_id: 1 })
  index({ grid_service_id: 1 })
  index({ container_id: 1 })
  index({ created_at: 1 })
end
