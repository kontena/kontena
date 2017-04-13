class ContainerLog
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String
  field :data, type: String
  field :name, type: String
  field :instance_number, type: Integer

  belongs_to :grid
  belongs_to :host_node
  belongs_to :grid_service
  belongs_to :container

  index({ grid_id: 1 }, { background: true })
  index({ host_node: 1 }, { background: true })
  index({ grid_service_id: 1 }, { background: true })
  index({ container_id: 1 }, { background: true })
  index({ name: 1 }, { background: true })
  index({ instance_number: 1 }, { background: true })
  index({ created_at: 1 }, { background: true })
end
