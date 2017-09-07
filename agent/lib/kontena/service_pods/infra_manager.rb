module Kontena
  module ServicePods
    class InfraManager
      include Kontena::Logging
      include Kontena::Helpers::WeaveHelper
      include Common

      attr_reader :service_pod

      def initialize(service_pod)
        @service_pod = service_pod
      end

      # @param service_container [Docker::Container,NilClass]
      # @return [Container]
      def ensure_infra(service_container = nil)
        infra_container = get_container(service_pod.service_id, service_pod.instance_number, 'infra')
        unless infra_container
          remove_container(service_container) if service_container
          config = service_pod.infra_config
          network_adapter.modify_create_opts(config) if service_pod.can_expose_ports?
          info "creating infra for service: #{service_pod.name_for_humans}"
          infra_container = Docker::Container.create(config)
        end

        unless infra_container.running?
          infra_container.start!
          network_adapter.attach_container(infra_container.id, infra_container.overlay_cidr) if service_pod.can_expose_ports?
        end

        infra_container
      end

      def terminate
        infra_container = get_container(service_pod.service_id, service_pod.instance_number, 'infra')
        if infra_container
          remove_container(infra_container)
          if infra_container.overlay_network && infra_container.overlay_cidr
            wait_network_ready?
            network_adapter.remove_container(container_id, infra_container.overlay_network, infra_container.overlay_cidr)
          end
        end
      end

      # @param container [Docker::Container]
      def remove_container(container)
        container.stop
        container.wait
        container.delete(v: true)
      end

      def network_adapter
        Celluloid::Actor[:network_adapter]
      end
    end
  end
end