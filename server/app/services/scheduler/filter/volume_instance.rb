module Scheduler
  module Filter
    class VolumeInstance
      include Logging

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @raise [Scheduler::Error]
      def for_service(service, instance_number, nodes)
        return nodes if service.service_volumes.empty?

        debug "filtering for service #{service.to_path}-#{instance_number}"

        filtered_nodes = nodes.dup

        service.service_volumes.each do |sv|
          if sv.volume
            filtered_nodes = filtered_nodes.select { |node|
              # Check if node has required volume instance
              node.volume_instances.where(name: sv.volume.name_for_service(service, instance_number)).exists?
            }
          end
        end
        debug "filtered nodes: #{filtered_nodes.map {|n| n.name}}"
        if filtered_nodes.empty?
          # No nodes with needed volumes, return all nodes
          nodes
        else
          filtered_nodes
        end

      end

    end
  end
end
