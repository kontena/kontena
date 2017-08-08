class HostNodeConnection
  include Mongoid::Document

  embedded_in :host_node

  field :close_code, type: Integer
  field :close_reason, type: String
end
