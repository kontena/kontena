require_relative '../helpers/event_log_helper'

module Kontena
  module ServicePods
    module Common
      include Kontena::Helpers::EventLogHelper

      # Docker create configuration for ServicePod
      # @param [ServicePod] service_pod
      # @raise [Kontena::Models::ServicePod::ConfigError]
      # @return [Hash] Docker create API JSON object
      def config_container(service_pod)
        opts = service_pod.service_config

        if service_pod.net == 'bridge'
          # blocks waiting for network
          opts = Kontena::NetworkAdapters::ContainerConfigurer.new(opts).configure
        end

        opts
      end

      # @param [Hash] opts
      def create_container(opts)
        Docker::Container.create(opts)
      end

      # @param [Docker::Container] container
      def cleanup_container(container)
        container.stop('timeout' => container.stop_grace_period)
        container.wait
        container.delete(v: true)
      end

      # @param [String] service_id
      # @param [Integer] instance_number
      # @param [String] type
      # @return [Docker::Container, NilClass]
      def get_container(service_id, instance_number, type = 'container')
        filters = JSON.dump({
          label: [
              "io.kontena.service.id=#{service_id}",
              "io.kontena.service.instance_number=#{instance_number}",
              "io.kontena.container.type=#{type}",
          ]
        })
        container = Docker::Container.all(all: true, filters: filters)[0]
        if container
          Docker::Container.get(container.id) rescue nil
        end
      end
    end
  end
end
