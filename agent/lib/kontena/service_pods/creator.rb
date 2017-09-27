require 'docker'
require 'celluloid'
require_relative 'common'
require_relative 'lifecycle_hook_manager'
require_relative '../logging'
require_relative '../helpers/weave_helper'
require_relative '../helpers/rpc_helper'

module Kontena
  module ServicePods
    class Creator
      include Kontena::Logging
      include Common
      include Kontena::Helpers::WeaveHelper
      include Kontena::Helpers::RpcHelper

      attr_reader :service_pod, :image_credentials, :hook_manager

      # @param service_pod [ServicePod]
      # @param hook_manager [LifecycleHookManager]
      def initialize(service_pod, hook_manager)
        @service_pod = service_pod
        @image_credentials = service_pod.image_credentials
        @hook_manager = hook_manager
        @hook_manager.track(service_pod)
      end

      # @return [Docker::Container]
      def perform
        info "creating service: #{service_pod.name}"
        ensure_image(service_pod.image_name)
        if service_pod.stateful?
          data_container = self.ensure_data_container(service_pod)
          service_pod.volumes_from << data_container.id
        end

        wait_until!("volumes exist", timeout: 30, interval: 1) {
          volumes_exist?(service_pod)
        }

        service_container = get_container(service_pod.service_id, service_pod.instance_number)

        wait_network_ready?

        if service_container
          hook_manager.on_pre_stop(service_container)
          info "removing previous version of service: #{service_pod.name_for_humans}"
          cleanup_container(service_container)
          log_service_pod_event("service:create_instance", "removed previous version of service #{service_pod.name_for_humans} instance")
        end

        hook_manager.on_pre_start

        service_config = config_container(service_pod)

        debug "creating container: #{service_pod.name}"
        service_container = create_container(service_config)
        debug "container created: #{service_pod.name}"
        log_service_pod_event("service:create_instance", "service #{service_pod.name_for_humans} instance created")
        if service_container.load_balanced? && service_container.instance_number == 1
          Celluloid::Notifications.publish('lb:ensure_config', service_container)
        elsif !service_container.load_balanced? && service_container.instance_number == 1
          Celluloid::Notifications.publish('lb:remove_config', service_container.service_name_for_lb)
        end

        service_container.start!
        info "service started: #{service_pod.name_for_humans}"
        log_service_pod_event("service:create_instance", "service #{service_pod.name_for_humans} instance started")

        Celluloid::Notifications.publish('service_pod:start', service_pod.name)
        Celluloid::Notifications.publish('container:publish_info', service_container)

        hook_manager.on_post_start(service_container)

        service_container
      end

      # @param [String] type
      # @param [String] data
      # @param [Integer] severity
      def log_service_pod_event(type, data, severity = Logger::INFO)
        super(service_pod.service_id, service_pod.instance_number, type, data, severity)
      end

      ##
      # @param [ServicePod] service_pod
      # @return [Container]
      def ensure_data_container(service_pod)
        data_container = get_container(service_pod.service_id, service_pod.instance_number, 'volume')
        unless data_container
          info "creating data volumes for service: #{service_pod.name_for_humans}"
          data_container = create_container(service_pod.data_volume_config)
          log_service_pod_event("service:create_instance", "created data volume container for #{service_pod.name_for_humans}")
        else
          log_service_pod_event("service:create_instance", "data volume container already exists for #{service_pod.name_for_humans}")
        end

        data_container
      end

      # @param [ServicePod] service_pod
      # @return [Boolean]
      def volumes_exist?(service_pod)
        volume_manager = Celluloid::Actor[:volume_manager]
        service_pod.volumes.each do |volume|
          if volume['name']
            return false unless volume_manager.volume_exist?(volume['name'], volume['driver'])
          end
        end
        true
      end

      # Make sure that image exists
      # @param [String] name
      # @param [Boolean] emit_event
      def ensure_image(name, emit_event = true)
        log_service_pod_event("service:create_instance", "pulling image #{name} for #{service_pod.name_for_humans}") if emit_event
        Celluloid::Actor[:image_pull_worker].ensure_image(name, service_pod.deploy_rev, image_credentials)
        log_service_pod_event("service:create_instance", "pulled image #{name} for #{service_pod.name_for_humans}") if emit_event
      end
    end
  end
end
