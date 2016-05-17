class GridServiceDeploy
  include Mongoid::Document
  include Mongoid::Timestamps

  field :started_at, type: DateTime
  field :finished_at, type: DateTime

  index({ grid_service_id: 1 })

  belongs_to :grid_service
end
