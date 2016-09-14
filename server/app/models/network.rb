require 'ipaddr'

class Network
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :subnet, type: String
  field :description, type: String
  field :multicast, type: Boolean, default: false
  field :internal, type: Boolean, default: false

  belongs_to :grid

  has_and_belongs_to_many :grid_services

  index({ name: 1 })

  validates_uniqueness_of :name, scope: [:grid_id]

end
