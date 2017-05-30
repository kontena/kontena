module Scheduler
  module Filter
    class Dependency

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @return [Array<HostNode>]
      def for_service(service, instance_number, nodes)
        candidates = nodes.dup
        return candidates unless has_dependencies?(service)

        if filter_by_volume?(service)
          filter_candidates_by_volume(candidates, service, instance_number)
        end
        if filter_by_net?(service)
          filter_candidates_by_net(candidates, service, instance_number)
        end

        candidates
      end

      # @param [Array<HostNode>] candidates
      # @param [GridService] service
      # @param [Integer] instance_number
      def filter_candidates_by_volume(candidates, service, instance_number)
        volumes = service.volumes_from.map{|v| v % [instance_number] }
        candidates.dup.each do |node|
          match = node.containers.includes(:grid_service).select { |c|
            next if c.grid_service.nil?

            name = "#{c.grid_service.name}-#{c.instance_number}"
            volumes.include?(name) && c.stack_name == service.stack.name
          }
          if match.empty?
            candidates.delete(node)
          end
        end
        if candidates.empty?
          raise Scheduler::Error, "Did not find any nodes for service dependency volumes_from: #{volumes}"
        end
      end

      # @param [Array<HostNode>] candidates
      # @param [GridService] service
      # @param [Integer] instance_number
      def filter_candidates_by_net(candidates, service, instance_number)
        net = service.net.sub('container:', '') % [instance_number]
        candidates.dup.each do |node|
          match = node.containers.includes(:grid_service).select { |c|
            next if c.grid_service.nil?

            name = "#{c.grid_service.name}-#{c.instance_number}"
            name == net && c.stack_name == service.stack.name
          }
          if match.empty?
            candidates.delete(node)
          end
        end
        if candidates.empty?
          raise Scheduler::Error, "Did not find any nodes for service dependency net: #{net}"
        end
      end

      # @param [GridService] service
      # @return [Boolean]
      def filter_by_volume?(service)
        service.volumes_from.size > 0
      end

      # @param [GridService] service
      # @return [Boolean]
      def filter_by_net?(service)
        !service.net.to_s.match(/\Acontainer:.+/).nil?
      end

      # @param [GridService] service
      # @return [Boolean]
      def has_dependencies?(service)
        return true if filter_by_volume?(service)
        return true if filter_by_net?(service)

        false
      end
    end
  end
end
