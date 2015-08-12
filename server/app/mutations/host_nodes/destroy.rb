
module HostNodes
  class Destroy < Mutations::Command

    required do
      model :host_node
      boolean :force, nils: true, default: false
    end

    def validate
      grid = self.host_node.grid
      if !self.force && self.host_node.node_number <= grid.initial_size
        add_error(:grid, :access_denied, "Cannot remove initial member without force")
        return
      end
    end

    def execute
      self.host_node.destroy
    end
  end
end
