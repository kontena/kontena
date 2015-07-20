class ContainerLog
  include Mongoid::Document
  include Mongoid::Timestamps

  field :type, type: String
  field :data, type: String
  field :name, type: String

  belongs_to :grid
  belongs_to :grid_service
  belongs_to :container

  index({ grid_id: 1 })
  index({ grid_service_id: 1 })
  index({ container_id: 1 })
  index({ name: 1 })
  index({ data: 'text' }, { background: true })
  index({ created_at: -1 }, { name: 'created_at_expire', expire_after_seconds: 3.months })
end
