require 'docker'
require_relative 'common'
require_relative '../logging'
require_relative 'lifecycle_hook_manager'

module Kontena
  module ServicePods
    class Stopper
      include Kontena::Logging
      include Common

      attr_reader :service_pod, :hook_manager

      # @param service_pod [ServicePod]
      # @param hook_manager [LifecycleHookManager]
      def initialize(service_pod, hook_manager)
        @service_pod = service_pod
        @hook_manager = hook_manager
        @hook_manager.track(service_pod)
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(service_pod.service_id, service_pod.instance_number)
        if service_container.running?
          info "stopping service: #{service_container.name_for_humans}"
          hook_manager.on_pre_stop(service_container)
          log_service_pod_event(
            service_pod.service_id, service_pod.instance_number,
            "service:stop_instance", "stopping service instance #{service_container.name_for_humans}"
          )
          service_container.stop!('timeout' => service_container.stop_grace_period)
          log_service_pod_event(
            service_pod.service_id, service_pod.instance_number,
            "service:stop_instance", "service instance #{service_container.name_for_humans} stopped succesfully"
          )
          info "stopped service: #{service_container.name_for_humans}"
        else
          log_service_pod_event(
            service_pod.service_id, service_pod.instance_number,
            "service:stop_instance", "service instance #{service_container.name_for_humans} is not running"
          )
        end

        Celluloid::Notifications.publish('service_pod:stop', service_container)

        service_container
      end
    end
  end
end
