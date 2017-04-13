class GridServiceInstance
  include Mongoid::Document
  include Mongoid::Timestamps

  field :instance_number, type: Integer

  # updated by master
  field :desired_state, type: String, default: 'initialized'.freeze
  field :deploy_rev, type: String

  # updated by agent
  field :rev, type: String
  field :state, type: String, default: 'initialized'.freeze
  field :error, type: String

  validates_uniqueness_of :instance_number, scope: [:grid_service_id]

  belongs_to :grid_service
  belongs_to :host_node

  index({ grid_service_id: 1 })
  index({ host_node_id: 1 })

  def self.has_node
    where(:host_node_id.ne => nil)
  end
end
