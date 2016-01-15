require 'docker'
require 'celluloid'
require_relative '../image_puller'
require_relative '../logging'

module Kontena
  module ServicePods
    class Creator
      include Kontena::Logging

      attr_reader :service_pod, :overlay_adapter, :image_credentials

      # @param [ServicePod] service_pod
      # @param [#modify_create_opts] overlay_adapter
      def initialize(service_pod, overlay_adapter = Kontena::WeaveAdapter.new)
        @service_pod = service_pod
        @overlay_adapter = overlay_adapter
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
        service_container = get_container(service_pod.name)

        sleep 1 until overlay_adapter.running?

        if service_container
          if service_uptodate?(service_container)
            info "service is up-to-date: #{service_pod.name}"
            notify_master(service_container, service_pod.deploy_rev)
            return service_container
          else
            info "removing previous version of service: #{service_pod.name}"
            self.cleanup_container(service_container)
          end
        end
        service_config = service_pod.service_config
        if service_pod.overlay_network
          overlay_adapter.modify_create_opts(service_config)
        end
        service_container = create_container(service_config)

        if service_pod.load_balanced? && service_pod.instance_number == 1
          Kontena::Pubsub.publish('lb:ensure_config', service_container)
        end

        service_container.start
        info "service started: #{service_pod.name}"

        Pubsub.publish('service_pod:start', service_pod.name)
        Pubsub.publish('container:publish_info', service_container)

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
      # @param [#modify_create_opts] overlay_adapter
      def self.perform_async(service_pod, overlay_adapter = Kontena::WeaveAdapter.new)
        self.new(service_pod, overlay_adapter).perform_async
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
          Kontena::Pubsub.publish('queue_worker:add_message', msg)
        end
      end

      ##
      # @param [ServicePod] service_pod
      # @return [Container]
      def ensure_data_container(service_pod)
        data_container = get_container(service_pod.data_volume_name)
        unless data_container
          info "creating data volumes for service: #{service_pod.name}"
          data_container = create_container(service_pod.data_volume_config)
        end

        data_container
      end

      # @param [Docker::Container] container
      def cleanup_container(container)
        container.stop
        container.wait
        container.delete(v: true)
      end

      # @return [Docker::Container, NilClass]
      def get_container(name)
        Docker::Container.get(name) rescue nil
      end

      # @param [Hash] opts
      def create_container(opts)
        ensure_image(opts['Image'])
        Docker::Container.create(opts)
      end

      # Make sure that image exists
      def ensure_image(name)
        image_puller = Kontena::ImagePuller.new
        image_puller.ensure_image(name, image_credentials)
      end

      # @param [Docker::Container] service_container
      # @return [Boolean]
      def service_uptodate?(service_container)
        return false if recreate_service_container?(service_container)
        return false if service_container.info['Config']['Image'] != service_pod.image_name
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
        service_container.restart_policy['Name'] == 'always' &&
            state['Running'] == false &&
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
        Pubsub.publish('queue_worker:add_message', msg)
      end
    end
  end
end
