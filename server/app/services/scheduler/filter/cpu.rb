module Scheduler
  module Filter
    class Cpu

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @return [Array<HostNode>]
      def for_service(service, instance_number, nodes)
        return nodes if service.cpus.nil?

        candidates = nodes.dup.select { |n|
          n.cpus.to_f >= service.cpus.to_f
        }

        if candidates.empty?
          raise Scheduler::Error, "Did not find any nodes with #{service.cpus} CPUs available"
        end

        candidates
      end
    end
  end
end
