require_relative '../../services/docker/container_creator'
require_relative '../../services/docker/container_starter'

module Containers
  class Create < Mutations::Command
    required do
      model :grid_service
      model :host_node
      string :name, nils: true
      string :deploy_rev
    end

    ##
    # @return [Container]
    def execute
      if self.name.nil?
        name = self.grid_service.name << (self.grid_service.containers.count + 1).to_s
      else
        name = self.name
      end

      creator = Docker::ContainerCreator.new(self.grid_service, self.host_node)
      container = creator.create_container(name, self.deploy_rev)

      starter = Docker::ContainerStarter.new(container)
      starter.start_container

      sleep 0.5 until container.reload.running?

      container
    rescue RpcClient::TimeoutError
      add_error(:node, :timeout, "Connection timeout: node #{self.host_node.node_id}")
    end
  end
end
