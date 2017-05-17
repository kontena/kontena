class HostNodeDriver
  include Mongoid::Document

  field :name, type: String
  field :version, type: String

  embedded_in :host_node
end
