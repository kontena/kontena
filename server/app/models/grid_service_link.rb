class GridServiceLink
  include Mongoid::Document

  field :alias, type: String

  embedded_in :grid_service
  belongs_to :linked_grid_service, class_name: 'GridService'

end