module Rpc
  class NodeVolumeHandler
    include Logging

    def initialize(grid)
      @grid = grid
    end

    # @param [String] id
    # @return [Array<Hash>]
    def list(id)
      node = @grid.host_nodes.find_by(node_id: id)
      raise "Node not found" unless node

      volumes = node.volume_instances.map { |v|
        VolumeSerializer.new(v).to_hash
      }.compact

      { volumes: volumes }
    end

    # @param [String] id
    # @param [Hash] volume
    def set_state(id, data)
      node = @grid.host_nodes.find_by(node_id: id)
      raise "Node not found" unless node

      volume_instance = node.volume_instances.find_by(id: data['volume_instance_id'])
      unless volume_instance
        volume_id = data['volume_id']
        if volume_id
          volume = @grid.volumes.find_by(id: volume_id)
          if volume
            volume_instance = VolumeInstance.create!(host_node: node, volume: volume, name: data['name'])
          else
            raise "Could not find volume with id: #{volume_id}"
          end
        end
      end

      { }
    end
  end
end
