class GridServiceRemoveWorker
  include Celluloid

  def perform(grid_service_id)
    grid_service = GridService.find_by(id: grid_service_id)
    if grid_service
      remove_grid_service(grid_service)
    end
  end

  # @param [GridService] grid_service
  def remove_grid_service(grid_service)
    prev_state = grid_service.state
    grid_service.set_state('deleting')
    grid_service.containers.scoped.each do |container|
      terminate_from_node(container.host_node, container.name)
    end

    wait_instance_removal(grid_service)

    grid_service.destroy
  end

  def wait_instance_removal(grid_service)
    Timeout::timeout(10) do
      sleep 1 until grid_service.reload.containers.scoped.count == 0
    end
  end

  # @param [HostNode] node
  # @return [Docker::ServiceTerminator]
  def terminate_from_node(node, service_name)
    terminator = Docker::ServiceTerminator.new(node)
    terminator.terminate_service_instance(service_name, {lb: true})
  end
end
