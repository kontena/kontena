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
        container_name = "#{service.name}-#{instance_number}"
        volumes = service.volumes_from.map{|v| v % [instance_number] }
        candidates.dup.each do |node|
          container_names = node.containers.map {|c| c.name}
          if !container_names.any?{|name| volumes.include?(name) }
            candidates.delete(node)
          end
        end
      end

      # @param [Array<HostNode>] candidates
      # @param [GridService] service
      # @param [Integer] instance_number
      def filter_candidates_by_net(candidates, service, instance_number)
        net = service.net % [instance_number]
        candidates.dup.each do |node|
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
    end
  end
end
