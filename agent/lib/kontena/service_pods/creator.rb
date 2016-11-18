require 'docker'
require 'celluloid'
require_relative 'common'
require_relative '../logging'
require_relative '../helpers/weave_helper'

module Kontena
  module ServicePods
    class Creator
      include Kontena::Logging
      include Common
      include Kontena::Helpers::WeaveHelper

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
        service_container = get_container(service_pod.service_id, service_pod.instance_number)

        wait_network_ready?

        if service_container
          if service_uptodate?(service_container)
            info "service is up-to-date: #{service_pod.name}"
            notify_master(service_container, service_pod.deploy_rev)
            Celluloid::Notifications.publish('lb:ensure_instance_config', service_container)
            return service_container
          else
            info "removing previous version of service: #{service_pod.name}"
            self.cleanup_container(service_container)
          end
        end
        service_config = service_pod.service_config

        Celluloid::Actor[:network_adapter].modify_create_opts(service_config)
        Celluloid::Actor[:network_adapter].modify_network_opts(service_config) unless service_pod.net == 'host'
        debug "creating container: #{service_pod.name}"
        service_container = create_container(service_config)
        debug "container created: #{service_pod.name}"
        if service_container.load_balanced? && service_container.instance_number == 1
          Celluloid::Notifications.publish('lb:ensure_config', service_container)
        end

        service_container.start
        info "service started: #{service_pod.name}"

        Celluloid::Notifications.publish('service_pod:start', service_pod.name)
        Celluloid::Notifications.publish('container:publish_info', service_container)

        self.run_hooks(service_container, 'post_start')

        service_container
      rescue => exc
        error "#{exc.class.name}: #{exc.message}"
        error "#{exc.backtrace.join("\n")}" if exc.backtrace
      end

      # @return [Celluloid::Future]
      def perform_async
        Celluloid::Future.new { self.perform }
      end

      # @param [ServicePod] service_pod
      def self.perform_async(service_pod)
        self.new(service_pod).perform_async
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
        error exc.message
        false
      end

      # @param [String] id
      # @param [Array<String>] lines
      # @param [String] type
      def log_hook_output(id, lines, type)
        lines.each do |chunk|
          msg = {
              event: 'container:log',
              data: {
                  id: id,
                  time: Time.now.utc.xmlschema,
                  type: type,
                  data: chunk
              }
          }
          Celluloid::Actor[:queue_worker].send_message(msg)
        end
      end

      ##
      # @param [ServicePod] service_pod
      # @return [Container]
      def ensure_data_container(service_pod)
        data_container = get_container(service_pod.service_id, service_pod.instance_number, 'volume')
        unless data_container
          info "creating data volumes for service: #{service_pod.name}"
          data_container = create_container(service_pod.data_volume_config)
        end

        data_container
      end

      # @param [Docker::Container] container
      def cleanup_container(container)
        container.stop('timeout' => 10)
        container.wait
        container.delete(v: true)
      end

      # @param [Hash] opts
      def create_container(opts)
        ensure_image(opts['Image'])
        Docker::Container.create(opts)
      end

      # Make sure that image exists
      # @param [String] name
      def ensure_image(name)
        Celluloid::Actor[:image_pull_worker].ensure_image(name, service_pod.deploy_rev, image_credentials)
      end

      # @param [Docker::Container] service_container
      # @return [Boolean]
      def service_uptodate?(service_container)
        return false if recreate_service_container?(service_container)
        return false if service_container.config['Image'] != service_pod.image_name
        return false if container_outdated?(service_container)
        return false if image_outdated?(service_pod.image_name, service_container)

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

      # @param [Docker::Container] service_container
      # @param [String] deploy_rev
      def notify_master(service_container, deploy_rev)
        msg = {
          event: 'container:event',
          data: {
            id: service_container.id,
            status: 'deployed',
            deploy_rev: deploy_rev
          }
        }
        Celluloid::Actor[:queue_worker].send_message(msg)
      end
    end
  end
end
