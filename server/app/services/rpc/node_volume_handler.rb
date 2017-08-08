module Rpc
  class NodeVolumeHandler
    include Celluloid
    include Logging

    # @params [HostNode] node
    def initialize(node)
      @node = node
    end

    # @return [Array<Hash>]
    def list
      node = HostNode.find(@node.id)

      raise "Node not found" unless node
      
      volumes = @node.volume_instances.map { |v|
        VolumeSerializer.new(v).to_hash
      }.compact

      { volumes: volumes }
    end

    # @param [Hash] volume
    def set_state(data)
      volume_instance = @node.volume_instances.find_by(id: data['volume_instance_id'])
      unless volume_instance
        volume_id = data['volume_id']
        if volume_id
          volume = @node.grid.volumes.find_by(id: volume_id)
          if volume
            volume_instance = VolumeInstance.create!(host_node: @node, volume: volume, name: data['name'])
          else
            raise "Could not find volume with id: #{volume_id}"
          end
        end
      end

      { }
    end
  end
end
