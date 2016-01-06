module HostNodes
  class Remove < Mutations::Command
    include Workers
    
    required do
      model :host_node
    end

    def execute
      grid = self.host_node.grid
      self.host_node.destroy

      if grid
        worker(:grid_scheduler).async.perform(grid.id)
      end
    end
  end
end
