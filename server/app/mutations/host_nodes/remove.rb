module HostNodes
  class Remove < Mutations::Command

    required do
      model :host_node
    end

    def execute
      grid = self.host_node.grid
      self.host_node.destroy

      if grid
        GridScheduler.new(grid).reschedule
      end
    end
  end
end
