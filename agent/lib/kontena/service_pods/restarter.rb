require 'docker'
require_relative 'common'
require_relative '../logging'

module Kontena
  module ServicePods
    class Restarter
      include Kontena::Logging
      include Common

      attr_reader :service_id, :instance_number

      # @param service_id [String]
      # @param instance_number [Integer]
      def initialize(service_id, instance_number)
        @service_id = service_id
        @instance_number = instance_number
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(service_id, instance_number)
        if service_container.running?
          info "restarting service: #{service_container.name_for_humans}"
          service_container.restart!('timeout' => service_container.stop_grace_period)
          log_service_pod_event(
            service_id, instance_number,
            "service:restart_instance", "service #{service_container.name_for_humans} instance restarted successfully"
          )
        else
          info "service not running: #{service_container.name_for_humans}"
          log_service_pod_event(
            service_id, instance_number,
            "service:restart_instance", "service #{service_container.name_for_humans} instance not running, restart is ignored"
          )
          return
        end

        Celluloid::Notifications.publish('service_pod:restart', service_container)

        service_container
      end
    end
  end
end
