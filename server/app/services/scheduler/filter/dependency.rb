module Scheduler
  module Filter
    class Dependency

      ##
      # @param [GridService] service
      # @param [String] container_name
      # @param [Array<HostNode>] nodes
      # @return [Array<HostNode>]
      def for_service(service, container_name, nodes)
        candidates = nodes.dup
        return candidates unless has_dependencies?(service)

        if filter_by_volume?(service)
          filter_candidates_by_volume(candidates, service, container_name)
        end
        if filter_by_net?(service)
          filter_candidates_by_net(candidates, service, container_name)
        end

        candidates
      end

      # @param [Array<HostNode>] candidates
      # @param [GridService] service
      # @param [String] container_name
      def filter_candidates_by_volume(candidates, service, container_name)
        i = container_number(container_name)
        volumes = service.volumes_from.map{|v| v % [i] }
        nodes.each do |node|
          container_names = node.containers.map {|c| c.name}
          if !container_names.any?{|name| volumes.include?(name) }
            candidates.delete(node)
          end
        end
      end

      # @param [Array<HostNode>] candidates
      # @param [GridService] service
      # @param [String] container_name
      def filter_candidates_by_net(candidates, service, container_name)
        i = container_number(container_name)
        net = service.net % [i]
        nodes.each do |node|
          container_names = node.containers.map {|c| c.name}
          if !container_names.include?(net)
            candidates.delete(node)
          end
        end
      end

      def filter_by_volume?(service)
        service.volumes_from.size > 0
      end

      def filter_by_net?(service)
        !service.net.to_s.match(/^container:.+/).nil?
      end

      # @param [GridService] service
      # @return [Boolean]
      def has_dependencies?(service)
        return true if filter_by_volume?(service)
        return true if filter_by_net?(service)

        false
      end

      def container_number(container_name)
        if match = container_name.match(/^.+-(\d+)$/)
          match[1]
        end
      end
    end
  end
end
