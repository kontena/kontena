require_relative 'common'

module HostNodes
  class Availability < Mutations::Command
    include Logging

    required do
      model :host_node
      string :availability, in: ['active', 'drain']
    end

    def execute
      # Trigger actions only if the availability really changes
      if self.host_node.availability != self.availability

        self.host_node.set(:availability => self.availability)

        case self.availability
        when 'active'
          start_stateful_services(self.host_node)
          # TODO Should this also trigger full re-scheduling or just wait for the next loop to do it?
        when 'drain'
          re_deploy_needed_services(self.host_node)
          stop_stateful_services(self.host_node)
        end
      end
      self.host_node.reload
    end

    # Re-deploy needed services, new deployments will filter out evacuated node
    def re_deploy_needed_services(host_node)
      services = find_services(host_node)
      services.each do |service|
        GridServiceDeploy.create!(grid_service: service)
      end
    end

    # Finds stateless services on a given node
    def find_services(host_node)
      services = host_node.grid_service_instances.map { |instance|
        instance.grid_service unless instance.grid_service.stateful?
      }.compact.uniq
    end

    def stop_stateful_services(host_node)
      host_node.grid_service_instances.each do |instance|
        if instance.grid_service.stateful?
          info "setting desired state to stopped for instance #{instance.grid_service.to_path}-#{instance.instance_number}"
          instance.set(desired_state: 'stopped')
          notify_node(instance.host_node) if instance.host_node
        end
      end
    end

    def notify_node(node)
      RpcClient.new(node.node_id).notify('/service_pods/notify_update', 'stop')
    end

    def start_stateful_services(host_node)
      info "checking if stateful services need to be started"
      host_node.grid_service_instances.each do |instance|
        # Stateful instances might have been stopped by evacuate
        if instance.grid_service.stateful? && instance.grid_service.running? && instance.desired_state == 'stopped'
          info "setting desired state to running for instance #{instance.grid_service.to_path}-#{instance.instance_number}"
          instance.set(desired_state: 'running')
          notify_node(instance.host_node) if instance.host_node
        end
      end
    end

  end
end
