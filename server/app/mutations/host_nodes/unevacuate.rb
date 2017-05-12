require_relative 'common'

module HostNodes
  class Unevacuate < Mutations::Command
    include Workers

    required do
      model :host_node
    end

    def validate
      add_error(:host_node, :not_evacuated, "Node #{self.host_node.name} is already evacuated") unless self.host_node.evacuated?
    end

    def execute
      self.host_node.set(:evacuated => false)

      start_stateful_services(self.host_node)
    end

    def start_stateful_services(host_node)
      host_node.grid_service_instances.each do |instance|
        # Stateful instances might have been stopped by evacuate
        if instance.grid_service.stateful? && instance.grid_service.running? && instance.desired_state == 'stopped'
          instance.set(desired_state: 'running')
          notify_node(instance.host_node) if instance.host_node
        end
      end
    end

    def notify_node(node)
      RpcClient.new(node.node_id).notify('/service_pods/notify_update', 'start')
    end
  end
end
