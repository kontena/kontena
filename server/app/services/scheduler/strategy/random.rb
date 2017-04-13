module Scheduler
  module Strategy
    class Random

      # @param [Integer] node_count
      # @param [Integer] instance_count
      def instance_count(node_count, instance_count)
        instance_count.to_i
      end

      # @return [ActiveSupport::Duration]
      def host_grace_period
        30.seconds
      end

      ##
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      def find_node(grid_service, instance_number, nodes)
        if grid_service.stateless?
          nodes.sample
        else
          prev_instance = grid_service.grid_service_instances.find_by(
            grid_service: grid_service, instance_number: instance_number
          )
          if prev_instance
            prev_instance.host_node
          else
            nodes.sample
          end
        end
      end
    end
  end
end
