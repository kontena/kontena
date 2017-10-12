module Scheduler
  module Filter
    class Port

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @return [Array<HostNode>]
      def for_service(service, instance_number, nodes)
        candidates = nodes.dup
        ports = service.ports.map { |p| p['node_port'] }
        nodes.each do |node|
          service_instances = node.grid_service_instances.includes(:grid_service).select { |i|
            i.grid_service && i.grid_service.ports.size > 0
          }
          service_instances.each do |s|
            unless s.grid_service_id == service.id && s.instance_number == instance_number
              if s.grid_service.ports.any? { |p| ports.include?(p['node_port']) }
                candidates.delete(node)
              end
            end
          end
        end

        if candidates.empty?
          raise Scheduler::Error, "Did not find any nodes with unused ports: #{ports}"
        end

        candidates
      end
    end
  end
end
