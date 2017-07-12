module Scheduler
  module Filter
    class Ephemeral
      include Logging

      ##
      # Filters nodes based on ephemeral status
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @raise [Scheduler::Error]
      def for_service(service, instance_number, nodes)
        return nodes unless service.stateful?

        nodes = nodes.reject{|n| n.ephemeral? && !n.grid_service_instances.find_by(grid_service: service, instance_number: instance_number)}

        if nodes.empty?
          raise Scheduler::Error, "Did not find any non-ephemeral nodes for stateful service"
        end

        nodes
      end

    end
  end
end
