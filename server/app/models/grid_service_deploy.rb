class GridServiceDeploy
  include Mongoid::Document
  include Mongoid::Timestamps

  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :reason, type: String

  index({ grid_service_id: 1 })
  index({ created_at: 1 })
  index({ started_at: 1 })

  belongs_to :grid_service
end
