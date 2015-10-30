require 'docker'
require_relative '../image_puller'

module Kontena
  module ServicePods
    class Creator

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
        if service_pod.stateful?
          data_container = self.ensure_data_container(service_pod)
          service_pod.volumes_from << data_container.id
        end

        service_container = get_container(service_pod.name)
        if service_container
          self.cleanup_container(service_container)
        end
        service_config = service_pod.service_config
        overlay_adapter.modify_create_opts(service_config)
        service_container = create_container(service_config)
        service_container.start

        Pubsub.publish('service_pod:start', service_pod.name)

        service_container
      rescue => exc
        puts "#{exc.class.name}: #{exc.message}"
        puts "#{exc.backtrace.join("\n")}" if exc.backtrace
      end

      # @return [Celluloid::Future]
      def perform_async
        Celluloid::Future.new { self.perform }
      end

      ##
      # @param [ServicePod] service_pod
      # @return [Container]
      def ensure_data_container(service_pod)
        data_container = get_container(service_pod.data_volume_name)
        unless data_container
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

      private

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
    end
  end
end
