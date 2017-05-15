module Scheduler
  module Filter
    class Availability

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @raise [Scheduler::Error]
      def for_service(service, instance_number, nodes)

        nodes = nodes.select { |n| 
          case n.availability
          when 'active'
            true
          when 'drain'
            false
          end
        }

        nodes
      end
    end

  end
end
