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
        return candidates if service.volumes_from.size == 0

        i = container_name.match(/^.+-(\d+)$/)[1]
        volumes = service.volumes_from.map{|v| v % [i] }
        nodes.each do |node|
          container_names = node.containers.map {|c| c.name}
          unless container_names.any?{|name| volumes.include?(name) }
            candidates.delete(node)
          end
        end

        candidates
      end
    end
  end
end
