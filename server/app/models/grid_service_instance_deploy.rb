class GridServiceInstanceDeploy
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  field :instance_number, type: Integer
  enum :deploy_state, [:created, :ongoing, :success, :error], default: :created
  field :error, type: String

  embedded_in :grid_service_deploy
  belongs_to :host_node
end
