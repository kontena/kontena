class StackDeploy
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  index({ stack_id: 1 })

  enum :deploy_state, [:created, :ongoing, :success, :error], default: :created

  belongs_to :stack
  has_many :grid_service_deploys
end
