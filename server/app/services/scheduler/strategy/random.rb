module Scheduler
  module Strategy
    class Random

      # @param [Integer] node_count
      # @param [Integer] instance_count
      def instance_count(node_count, instance_count)
        instance_count.to_i
      end

      ##
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      def find_node(grid_service, container_name, nodes)
        if grid_service.stateless?
          nodes.sample
        else
          prev_container = grid_service.containers.volumes.find_by(
            name: "#{grid_service.name}-#{instance_number}-volumes"
          )
          if prev_container
            prev_container.host_node
          else
            nodes.sample
          end
        end
      end
    end
  end
end
