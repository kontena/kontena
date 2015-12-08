class GridServiceSecret
  include Mongoid::Document

  field :secret, type: String
  field :name, type: String
  field :type, type: String, default: 'env'

  embedded_in :grid_service
end
