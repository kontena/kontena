require_relative 'high_availability'

module Scheduler
  module Strategy
    class Daemon < Strategy::HighAvailability

      # @param [Integer] node_count
      # @param [Integer] instance_count
      def instance_count(node_count, instance_count)
        node_count.to_i * instance_count.to_i
      end

      # @return [ActiveSupport::Duration]
      def host_grace_period
        10.minutes
      end

      # @param [Array<Scheduler::Node>] nodes
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      def sort_candidates(nodes, grid_service, instance_number)
        total_instances = nodes.size * grid_service.container_count
        service_instances = grid_service.grid_service_instances.to_a
        service_instance = service_instances.find { |i| i.instance_number == instance_number }

        nodes.sort_by { |node|
          if service_instance && service_instance.host_node_id == node.id
            instance_rank = -1
          else
            instance_rank = service_instances.select { |i| i.host_node_id == node.id && i.instance_number <= total_instances }.size
          end

          [instance_rank + node.schedule_counter, node.node_number]
        }
      end
    end
  end
end
