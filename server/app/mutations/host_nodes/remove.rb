require_relative 'common'

module HostNodes
  class Remove < Mutations::Command
    include Workers
    include Common

    required do
      model :host_node
    end

    def execute
      grid = self.host_node.grid
      self.host_node.destroy

      if grid
        notify_grid(grid)
      end
    end
  end
end
