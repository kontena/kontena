require_relative 'common'

module HostNodes
  class Update < Mutations::Command

    include Common

    required do
      model :host_node
    end

    common_inputs

    def execute
      set_common_params(self.host_node)

      self.host_node.save

      notify_grid(self.host_node.grid)

      self.host_node
    end
  end
end
