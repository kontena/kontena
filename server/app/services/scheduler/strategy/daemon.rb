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

      # @param [Array<HostNode>] nodes
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      def sort_candidates(nodes, grid_service, instance_number)
        nodes.sort_by{|node|
          [node.schedule_counter, node.node_number]
        }
      end
    end
  end
end
