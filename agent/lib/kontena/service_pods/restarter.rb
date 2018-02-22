require 'docker'
require_relative 'common'
require_relative '../logging'

module Kontena
  module ServicePods
    class Restarter
      include Kontena::Logging
      include Common

      attr_reader :service_pod

      # @param service_id [String]
      # @param instance_number [Integer]
      def initialize(service_pod)
        @service_pod = service_pod
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(service_pod.service_id, service_pod.instance_number)
        if service_container.running?
          info "restarting service: #{service_container.name_for_humans}"
          service_container.restart!('timeout' => service_container.stop_grace_period)
          log_service_pod_event(
            service_pod.service_id, service_pod.instance_number,
            "service:restart_instance", "service #{service_container.name_for_humans} instance restarted successfully"
          )
        else
          info "service not running: #{service_container.name_for_humans}"
          log_service_pod_event(
            service_pod.service_id, service_pod.instance_number,
            "service:restart_instance", "service #{service_container.name_for_humans} instance not running, restart is ignored"
          )
          return
        end

        service_container
      end
    end
  end
end
