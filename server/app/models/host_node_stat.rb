class HostNodeStat
  include Mongoid::Document
  include Mongoid::Timestamps

  field :load, type: Hash
  field :memory, type: Hash
  field :filesystem, type: Array
  field :usage, type: Hash

  belongs_to :grid
  belongs_to :host_node

  index({ grid_id: 1 })
  index({ host_node_id: 1 })
end
