class GridLogsOpts
  include Mongoid::Document

  field :forwarder, type: String
  field :opts, type: Hash, default: {}

  embedded_in :grid
end
