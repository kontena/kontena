module Volumes
  class Delete < Mutations::Command

    required do
      model :volume, class: Volume
    end

    def validate
      unless self.volume.services.empty?
        add_error(self.volume.name, :volume_in_use, "Volume still in use in services #{self.volume.services.map{|s| s.to_path}}")
      end
    end

    def execute
      nodes = self.volume.volume_instances.map { |instance| instance.host_node}.uniq
      self.volume.destroy
      notify_nodes(nodes)
    end

    def notify_nodes(nodes)
      nodes.each do |node|
        RpcClient.new(node.node_id).notify('/volumes/notify_update', 'remove') if node.connected?
      end
    end
    
  end

end
