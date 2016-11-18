class GridServiceDeploy
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :reason, type: String
  enum :deploy_state, [:created, :ongoing, :success, :error], default: :created

  index({ grid_service_id: 1 })
  index({ created_at: 1 })
  index({ started_at: 1 })

  belongs_to :grid_service
end
