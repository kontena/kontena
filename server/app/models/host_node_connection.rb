class HostNodeConnection
  include Mongoid::Document

  embedded_in :host_node

  field :opened, type: Boolean # false => websocket open was rejected by server
  field :close_code, type: Integer
  field :close_reason, type: String
end
