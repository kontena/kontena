module Kontena
  module ServicePods
    class InfraManager
      include Kontena::Logging
      include Kontena::Helpers::WeaveHelper
      include Common

      CONTAINER_TYPE = 'infra'.freeze

      attr_reader :service_pod

      # @param service_pod [ServicePod]
      def initialize(service_pod)
        @service_pod = service_pod
      end

      # @param service_container [Docker::Container,NilClass]
      # @return [Container]
      def ensure_infra(service_container = nil)
        infra_container = get_container(service_pod.service_id, service_pod.instance_number, CONTAINER_TYPE)
        unless infra_container
          remove_container(service_container) if service_container
          infra_container = create_infra
        end

        start_infra(infra_container) unless infra_container.running?

        infra_container
      end

      # @return [Docker::Container]
      def create_infra
        network_adapter.modify_create_opts(config) if service_pod.can_expose_ports?
        info "creating infra for service: #{service_pod.name_for_humans}"
        Docker::Container.create(config)
      end

      # @param infra_container [Docker::Container]
      def start_infra(infra_container)
        infra_container.start!
        attach_network(infra_container) if infra_container.overlay_network && infra_container.overlay_cidr
      end

      def terminate
        infra_container = get_container(service_pod.service_id, service_pod.instance_number, CONTAINER_TYPE)
        if infra_container
          detach_network(infra_container) if infra_container.overlay_network && infra_container.overlay_cidr
          remove_container(infra_container)
        end
      end

      # @param container [Docker::Container]
      def remove_container(container)
        container.stop
        container.wait
        container.delete(v: true)
      end

      # @param infra_container [Docker::Container]
      def attach_network(infra_container)
        wait_network_ready?
        network_adapter.attach_container(infra_container.id, infra_container.overlay_cidr)
      end

      # @param infra_container [Docker::Container]
      def detach_network(infra_container)
        wait_network_ready?
        network_adapter.remove_container(infra_container.id, infra_container.overlay_network, infra_container.overlay_cidr)
      end

      def network_adapter
        Celluloid::Actor[:network_adapter]
      end
    end
  end
end