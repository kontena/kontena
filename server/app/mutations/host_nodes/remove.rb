require_relative 'common'

module HostNodes
  class Remove < Mutations::Command
    include Common

    required do
      model :host_node
    end

    def execute
      grid = self.host_node.grid
      
      self.host_node.destroy

      notify_grid(grid) if grid
    end
  end
end
