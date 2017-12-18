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

      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<Scheduler::Node>] nodes
      # @return [Scheduler::Node,NilClass]
      def find_stateless_node(grid_service, instance_number, nodes)
        prev_instance = grid_service.grid_service_instances.has_node.find_by(
          instance_number: instance_number
        )
        if prev_instance
          node = nodes.find { |n| n.node == prev_instance.host_node }
          unless node
            selector = (instance_number.to_f / nodes.size.to_f).floor
            candidates = self.sort_candidates(nodes, grid_service, instance_number)
            node = candidates.select { |c| c.schedule_counter <= selector }.last
          end
          node
        else
          candidates = self.sort_candidates(nodes, grid_service, instance_number)
          candidates.first
        end
      end

      # @param [Array<Scheduler::Node>] nodes
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      def sort_candidates(nodes, grid_service, instance_number)
        nodes.sort_by { |node|
          [node.schedule_counter, node.node_number]
        }
      end
    end
  end
end
