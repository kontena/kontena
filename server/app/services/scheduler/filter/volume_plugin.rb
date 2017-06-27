module Scheduler
  module Filter
    class VolumePlugin

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
            driver, version = sv.volume.driver.split(':', 2)
            {'name' => driver, 'version' => version}
          end
        }.compact

        nodes = nodes.select { |node|
          all_drivers_present?(needed_drivers, node)
        }

        if nodes.empty?
          raise Scheduler::Error, "Did not find any nodes with required volume drivers: #{needed_drivers}"
        end

        nodes
      end

      # Checks if all needed drivers are present on a node
      # @param [Hash] needed_drivers
      # @param [HostNode] node
      def all_drivers_present?(needed_drivers, node)
        needed_drivers.reject { |nd|
          !node.volume_drivers.find_index { |vd|
            if nd['version']
              vd['name'] == nd['name'] && vd['version'] == nd['version']
            else
              vd['name'] == nd['name']
            end
          }.nil?
        }.empty?
      end
    end
  end
end
