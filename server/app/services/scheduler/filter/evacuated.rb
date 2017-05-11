module Scheduler
  module Filter
    class Affinity

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @raise [Scheduler::Error]
      def for_service(service, instance_number, nodes)
        nodes = nodes.select { |n| !n.evacuated?}

        nodes
      end
    end

  end
end
