class GridServiceDeployOpt
  include Mongoid::Document

  field :wait_for_port, type: Integer
  field :min_health, type: Float, default: 0.6

  embedded_in :grid_service
end
