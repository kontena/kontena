require_relative 'common'

module HostNodes
  class Evacuate < Mutations::Command
    include Workers

    required do
      model :host_node
    end

    def validate
      add_error(:host_node, :already_evacuated, "Node #{self.host_node.name} is already evacuated") if self.host_node.evacuated?
    end

    def execute
      self.host_node.set(:evacuated => true)

      re_deploy_needed_services(self.host_node)
      stop_stateless_services(self.host_node)
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

    def stop_stateless_services(host_node)
      host_node.grid_service_instances.each do |instance| 
        if instance.grid_service.stateful?
          instance.set(desired_state: 'stopped')
          notify_node(instance.host_node) if instance.host_node
        end
      end
    end

    def notify_node(node)
      RpcClient.new(node.node_id).notify('/service_pods/notify_update', 'stop')
    end
  end
end
