class StackDeploy
  include Mongoid::Document
  include Mongoid::Timestamps

  index({ stack_id: 1 })

  belongs_to :stack
  has_many :grid_service_deploys, dependent: :destroy
end
