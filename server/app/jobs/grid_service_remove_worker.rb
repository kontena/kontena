class GridServiceRemoveWorker
  include Celluloid
  include Logging
  include WaitHelper

  def perform(grid_service_id)
    grid_service = GridService.find_by(id: grid_service_id)
    if grid_service
      remove_grid_service(grid_service)
    end
  end

  # @param [GridService] grid_service
  def remove_grid_service(grid_service)
    begin
      prev_state = grid_service.state
      grid_service.set_state('deleting')
      grid_service.containers.scoped.each do |container|
        terminate_from_node(container.host_node, grid_service, container.instance_number)
      end

      wait_instance_removal(grid_service, grid_service.containers.scoped.count * 30)

      grid_service.destroy
    rescue Timeout::Error
      error "service remove timed out #{grid_service.to_path}"
      grid_service.set_state(prev_state)
    end
  end

  # @param [GridService] grid_service
  # @param [Integer] timeout
  def wait_instance_removal(grid_service, timeout)
    wait_until!(timeout: timeout) { grid_service.reload.containers.scoped.count == 0 }
  end

  # @param [HostNode] node
  # @param [GridService] service
  # @param [Integer] instance_number
  # @return [Docker::ServiceTerminator]
  def terminate_from_node(node, service, instance_number)
    terminator = Docker::ServiceTerminator.new(node)
    terminator.terminate_service_instance(service, instance_number, {lb: true})
  end
end
