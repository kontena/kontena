
class DockerPlugin
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :alias, type: String
  field :config, type: Array
  field :label, type: String

  has_many :docker_plugin_statuses, dependent: :destroy

  belongs_to :grid

  index({ grid_id: 1 })
  index({ name: 1 }, { unique: true })

end