class GridServiceInstance
  include Mongoid::Document
  include Mongoid::Timestamps

  field :instance_number, type: Integer
  field :deploy_rev, type: String
  field :rev, type: String
  field :desired_state, type: String, default: 'initialized'.freeze
  field :state, type: String, default: 'initialized'.freeze

  belongs_to :grid_service
  belongs_to :host_node

  index({ grid_service_id: 1 })
  index({ host_node_id: 1 })
end
