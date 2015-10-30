module GridServices
  class Delete < Mutations::Command
    required do
      model :current_user, class: User
      model :grid_service
    end

    def validate

      linked_to_services = self.grid_service.linked_to_services
      if linked_to_services.count > 0
        add_error(:service, :invalid, "Cannot delete service that is linked to another service (#{linked_to_services.map{|s| s.name}.join(', ')})")
      end
    end

    def execute
      prev_state = self.grid_service.state
      begin
        self.grid_service.set_state('deleting')

        self.grid_service.containers.scoped.each do |container|
          terminate_from_node(container.host_node, container.name)
        end
      rescue => exc
        self.grid_service.set_state(prev_state)
        raise exc
      end
      self.grid_service.destroy
    end

    ##
    # @param [HostNode] node
    # @return [Docker::ContainerRemover]
    def terminate_from_node(node, service_name)
      terminator = Docker::ServiceTerminator.new(node)
      terminator.terminate_service_instance(service_name)
    end
  end
end
