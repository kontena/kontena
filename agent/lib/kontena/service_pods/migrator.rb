module Kontena
  module ServicePods
    class Migrator

      # @param service_container [Docker::Container]
      # @return [Docker::Container]
      def self.migrate_container(service_container)
        service_container.update({
          'RestartPolicy' => {}
        })

        service_container
      end

      # @param service_container [Docker::Container]
      def self.legacy_container?(service_container)
        return true if service_container.host_config != {}

        false
      end
    end
  end
end