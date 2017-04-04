module Scheduler
  module Filter
    class VolumePlugin
      include Logging

      ##
      # Filters nodes that have the needed volume driver plugins
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @raise [Scheduler::Error]
      def for_service(service, instance_number, nodes)
        return nodes if service.service_volumes.empty?

        needed_drivers = service.service_volumes.map { |sv|
          if sv.volume
            sv.volume.driver
          end
        }.compact

        nodes = nodes.select { |node|
          volume_drivers = node.volume_drivers.map { |v| v['name'] }
          (needed_drivers - volume_drivers).empty?
        }

        if nodes.empty?
          raise Scheduler::Error, "Did not find any nodes with required volume drivers: #{needed_drivers}"
        end

        nodes
      end

    end
  end
end
