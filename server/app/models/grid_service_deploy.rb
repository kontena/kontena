class GridServiceDeploy
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :reason, type: String
  enum :deploy_state, [:created, :ongoing, :success, :error], default: :created

  embeds_many :grid_service_instance_deploys

  index({ grid_service_id: 1 }, { background: true })
  index({ created_at: 1 }, { background: true })
  index({ started_at: 1 }, { background: true })

  belongs_to :grid_service
  belongs_to :stack_deploy
end
