require 'httpclient'

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
      grid = self.host_node.grid
      self.host_node.destroy

      if grid.host_nodes.count == 0
        grid.update_attribute(:discovery_url, discovery_url(grid.initial_size))
      end

      self.host_node
    end

    ##
    # @return [String]
    def discovery_url(initial_size)
      HTTPClient.new.get_content("https://discovery.etcd.io/new?size=#{initial_size}")
    end
  end
end
