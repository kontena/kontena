require_relative 'common'

module HostNodes
  class Update < Mutations::Command
    include Common
    include Logging

    required do
      model :host_node
    end

    optional do
      string :availability, in: [HostNode::Availability::ACTIVE, HostNode::Availability::DRAIN]
    end

    common_inputs

    def execute
      set_common_params(self.host_node)

      self.host_node.save

      notify_grid(self.host_node.grid)

      # Update availability if given and trigger appropriate actions
      if self.availability && self.host_node.availability != self.availability

        self.host_node.set(:availability => self.availability)

        # Trigger needed action for stateful services, scheduling loop handles stateles services
        case self.availability
        when HostNode::Availability::ACTIVE
          start_stateful_services(self.host_node)
        when HostNode::Availability::DRAIN
          stop_stateful_services(self.host_node)
        end
      end

      self.host_node.reload
    end

    def stop_stateful_services(host_node)
      host_node.grid_service_instances.each do |instance|
        if instance.grid_service.stateful?
          info "setting desired state to stopped for instance #{instance.grid_service.to_path}-#{instance.instance_number}"
          instance.set(desired_state: 'stopped')
          notify_service_instance(instance, 'stop')
        end
      end
    end

    # @param instance [GridServiceInstance]
    def notify_service_instance(instance, action)
      if instance.host_node
        instance.host_node.rpc_client.notify('/service_pods/notify_update', action)
      end
    end

    def start_stateful_services(host_node)
      info "checking if stateful services need to be started"
      host_node.grid_service_instances.each do |instance|
        # Stateful instances might have been stopped by evacuate
        if instance.grid_service.stateful? && instance.grid_service.running? && instance.desired_state == 'stopped'
          info "setting desired state to running for instance #{instance.grid_service.to_path}-#{instance.instance_number}"
          instance.set(desired_state: 'running')
          notify_service_instance(instance, 'start')
        end
      end
    end
  end
end
