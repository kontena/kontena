require 'docker'
require_relative 'common'
require_relative 'lifecycle_hook_manager'
require_relative '../logging'

module Kontena
  module ServicePods
    class Starter
      include Kontena::Logging
      include Common

      attr_reader :service_pod, :hook_manager

      # @param [ServicePod] service_pod
      def initialize(service_pod)
        @service_pod = service_pod
        @hook_manager = Kontena::ServicePods::LifecycleHookManager.new(service_pod)
      end

      # @return [Docker::Container]
      def perform
        service_container = get_container(service_pod.service_id, service_pod.instance_number)
        unless service_container.running?
          info "starting service: #{service_container.name_for_humans}"
          log_service_pod_event(
            service_pod.service_id, service_pod.instance_number,
            "service:start_instance", "starting service instance #{service_container.name_for_humans}"
          )
          hook_manager.on_pre_start
          service_container.start!
          log_service_pod_event(
            service_pod.service_id, service_pod.instance_number,
            "service:start_instance", "service instance #{service_container.name_for_humans} started successfully"
          )
        end

        Celluloid::Notifications.publish('service_pod:start', service_container)

        service_container
      end
    end
  end
end
