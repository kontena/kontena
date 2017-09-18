module Kontena
  module ServicePods
    class Migrator
      include Kontena::Logging

      # @param service_container [Docker::Container]
      def initialize(service_container)
        @service_container = service_container
      end

      # @return [Docker::Container]
      def migrate
        remove_restart_policy if @service_container.autostart?
      end

      def remove_restart_policy
        info "removing restart policy from container #{@service_container.name_for_humans}"
        @service_container.update({
          'RestartPolicy' => {
            'Name' => 'no',
            'MaximumRetryCount' => 0
          }
        })
        @service_container.reload
      end
    end
  end
end