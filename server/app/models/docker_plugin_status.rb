class DockerPluginStatus
  include Mongoid::Document
  include Mongoid::Timestamps

  field :status, type: String
  field :error, type: String

  belongs_to :docker_plugin
  belongs_to :host_node

  index({ grid_id: 1 })
  index({ name: 1 }, { unique: true })

end