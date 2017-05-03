module Scheduler
  module Strategy
    module Common

      attr_reader :mode

      # @param [Symbol] mode
      def initialize(mode = :scheduler)
        @mode = mode
      end

      def deployment?
        @mode == :deployment
      end

      # @param [Integer] node_count
      # @param [Integer] instance_count
      def instance_count(node_count, instance_count)
        instance_count.to_i
      end

      # @return [ActiveSupport::Duration]
      def host_grace_period
        1.day
      end

      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<Scheduler::Node>] nodes
      # @return [HostNode,NilClass]
      def find_node(grid_service, instance_number, nodes)

      end
    end
  end
end