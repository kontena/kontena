module Volumes
  class PluginInstall < Mutations::Command


    required do
      model :grid, class: Grid
      string :name
    end

    optional do
      string :alias_name
      array :config do
        string
      end
      string :label
    end

    def validate

    end

    def execute
      # TODO
      # - Should each node be installed in parallel?
      # - Collect node results
      self.grid.host_nodes.connected.reject { |node| self.label && !node.labels.include?(self.label) }.each do |node|
        begin
          response = RpcClient.new(node.node_id).request('/plugins/install', self.name, self.config, self.alias_name)
          if response.key?('error')
            add_error(:install, :failed, "Plugin #{self.name} installation failed on node #{node.name}: #{response['error']}")
          end
        rescue => exc
          add_error(:install, :failed, "Plugin #{self.name} installation failed on node #{node.name}: #{exc.message}")
        end

      end
    end

  end

end
