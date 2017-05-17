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
    end

    def validate
      
    end

    def execute
      puts "****** install mutation"
      self.grid.host_nodes.connected.each do |node|
        puts "installing plugin #{self.name} to node #{node.name}"
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
