require 'docker'
require 'celluloid'
require_relative 'common'
require_relative '../logging'
require_relative '../helpers/weave_helper'
require_relative '../helpers/port_helper'
require_relative '../helpers/rpc_helper'

module Kontena
  module ServicePods
    class Creator
      include Kontena::Logging
      include Common
      include Kontena::Helpers::WeaveHelper
      include Kontena::Helpers::PortHelper
      include Kontena::Helpers::RpcHelper

      attr_reader :service_pod, :image_credentials

      # @param [ServicePod] service_pod
      def initialize(service_pod)
        @service_pod = service_pod
        @image_credentials = service_pod.image_credentials
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
          if service_uptodate?(service_container)
            info "service is up-to-date: #{service_pod.name_for_humans}"
            Celluloid::Notifications.publish('lb:ensure_instance_config', service_container)
            log_service_pod_event("service:create_instance", "service instance #{service_pod.name_for_humans} is up-to-date")
            return service_container
          else
            info "removing previous version of service: #{service_pod.name_for_humans}"
            self.cleanup_container(service_container)
            log_service_pod_event("service:create_instance", "removed previous version of service #{service_pod.name_for_humans} instance")
          end
        end
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

        service_container.start
        info "service started: #{service_pod.name_for_humans}"
        log_service_pod_event("service:create_instance", "service #{service_pod.name_for_humans} instance started")

        Celluloid::Notifications.publish('service_pod:start', service_pod.name)
        Celluloid::Notifications.publish('container:publish_info', service_container)

        if service_pod.wait_for_port
          info "waiting for port #{service_pod.name_for_humans}:#{service_pod.wait_for_port} to respond"
          log_service_pod_event("service:create_instance", "waiting for #{service_pod.name_for_humans} port #{service_pod.wait_for_port} to respond")
          wait_for_port(service_container, service_pod.wait_for_port)
          info "port #{service_pod.name_for_humans}:#{service_pod.wait_for_port} is responding"
          log_service_pod_event("service:create_instance", "#{service_pod.name_for_humans} port #{service_pod.wait_for_port} is responding")
        end
        self.run_hooks(service_container, 'post_start')

        service_container
      end

      # @param [Docker::Container] service_container
      # @param [String] type
      # @return [Boolean]
      def run_hooks(service_container, type)
        service_pod.hooks.each do |hook|
          if hook['type'] == type
            info "running #{type} hook: #{hook['cmd']}"
            command = ['/bin/sh', '-c', hook['cmd']]
            log_hook_output(service_container.id, ["running #{type} hook: #{hook['cmd']}"], 'stdout')
            stdout, stderr, exit_code = service_container.exec(command)
            log_hook_output(service_container.id, stdout, 'stdout')
            log_hook_output(service_container.id, stderr, 'stderr')
            if exit_code != 0
              raise "Failed to execute hook: #{hook['cmd']}"
            end
          end
        end
        true
      rescue => exc
        log_service_pod_event("service:create_instance", exc.message, Logger::ERROR)
        error exc.message
        false
      end

      # @param [String] id
      # @param [Array<String>] lines
      # @param [String] type
      def log_hook_output(id, lines, type)
        lines.each do |chunk|
          data = {
              id: id,
              time: Time.now.utc.xmlschema,
              type: type,
              data: chunk
          }
          rpc_client.async.notification('/containers/log', [data])
        end
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

      def volumes_exist?(service_pod)
        volume_manager = Celluloid::Actor[:volume_manager]
        service_pod.volumes.each do |volume|
          if volume['name']
            return false unless volume_manager.volume_exist?(volume['name'])
          end
        end
        true
      end

      # @param [Docker::Container] container
      def cleanup_container(container)
        container.stop('timeout' => 10)
        container.wait
        container.delete(v: true)
      end

      # Docker create configuration for ServicePod
      # @param [ServicePod] service_pod
      # @return [Hash] Docker create API JSON object
      def config_container(service_pod)
        service_config = service_pod.service_config

        unless service_pod.net == 'host'
          network_adapter.modify_create_opts(service_config)
        end

        service_config
      end

      # @param [Hash] opts
      def create_container(opts)
        ensure_image(opts['Image'], false)
        Docker::Container.create(opts)
      end

      # Make sure that image exists
      # @param [String] name
      # @param [Boolean] emit_event
      def ensure_image(name, emit_event = true)
        log_service_pod_event("service:create_instance", "pulling image #{name} for #{service_pod.name_for_humans}") if emit_event
        Celluloid::Actor[:image_pull_worker].ensure_image(name, service_pod.deploy_rev, image_credentials)
        log_service_pod_event("service:create_instance", "pulled image #{name} for #{service_pod.name_for_humans}") if emit_event
      end

      # @param [Docker::Container] service_container
      # @return [Boolean]
      def service_uptodate?(service_container)
        return false unless service_container.running?
        return false if recreate_service_container?(service_container)
        return false if service_container.config['Image'] != service_pod.image_name
        return false if container_outdated?(service_container)
        return false if image_outdated?(service_pod.image_name, service_container)
        return false if labels_outdated?(service_pod.labels, service_container)

        true
      end

      # @param [Docker::Container] service_container
      # @return [Boolean]
      def container_outdated?(service_container)
        updated_at = DateTime.parse(service_pod.updated_at)
        created = DateTime.parse(service_container.info['Created']) rescue nil
        return true if created.nil?
        return true if created < updated_at

        false
      end

      # @param [String] image_name
      # @param [Docker::Container] service_container
      # @return [Boolean]
      def image_outdated?(image_name, service_container)
        image = Docker::Image.get(image_name) rescue nil
        return true unless image

        container_created = DateTime.parse(service_container.info['Created']) rescue nil
        image_created = DateTime.parse(image.info['Created'])
        return true if image_created > container_created

        false
      end

      # @param [Docker::Container] service_container
      # @return [Boolean]
      def recreate_service_container?(service_container)
        state = service_container.state
        service_container.autostart? &&
            !service_container.running? &&
            (!state['Error'].empty? || state['ExitCode'].to_i != 0)
      end

      # @param [Hash] labels Labels of the service pod
      # @param [Docker::Container] service_container
      def labels_outdated?(labels, service_container)
        return true if labels['io.kontena.load_balancer.name'] != service_container.labels['io.kontena.load_balancer.name']

        false
      end

      # @param [Docker::Container] service_container
      # @param [Integer] port
      def wait_for_port(service_container, port)
        ip = service_container.overlay_ip
        ip = '127.0.0.1' unless ip
        Timeout.timeout(300) do
          sleep 1 until container_port_open?(ip, port)
        end
      end
    end
  end
end
