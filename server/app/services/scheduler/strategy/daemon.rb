require_relative 'high_availability'

module Scheduler
  module Strategy
    class Daemon < Strategy::HighAvailability

      # @param [Integer] node_count
      # @param [Integer] instance_count
      def instance_count(node_count, instance_count)
        node_count.to_i * instance_count.to_i
      end

      # @param [Array<HostNode>] nodes
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      def sort_candidates(nodes, grid_service, instance_number)
        nodes.sort_by{|node|
          node.schedule_counter
        }
      end
    end
  end
end
