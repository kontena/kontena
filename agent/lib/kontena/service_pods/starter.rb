require 'docker'
require_relative 'common'
require_relative '../logging'

module Kontena
  module ServicePods
    class Starter
      include Kontena::Logging
      include Common

      attr_reader :service_id, :instance_number

      # @param [String] service_id
      # @param [Integer] instance_number
      def initialize(service_id, instance_number)
        @service_id = service_id
        @instance_number = instance_number
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(self.service_id, self.instance_number)
        unless service_container.running?
          info "starting service: #{service_container.name_for_humans}"
          log_service_pod_event(
            self.service_id, self.instance_number,
            "service:start_instance", "starting service instance #{service_container.name_for_humans}"
          )
          service_container.restart('timeout' => 10)
          log_service_pod_event(
            self.service_id, self.instance_number,
            "service:start_instance", "service instance #{service_container.name_for_humans} started successfully"
          )
        end

        Celluloid::Notifications.publish('service_pod:start', service_container)

        service_container
      end
    end
  end
end
