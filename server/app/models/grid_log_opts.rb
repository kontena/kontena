class GridLogsOpts
  include Mongoid::Document

  field :driver, type: String
  field :opts, type: Hash, default: {}

  embedded_in :grid
end
