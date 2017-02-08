require 'celluloid'
require_relative '../services/logging'

class ContainerCleanupJob
  include Celluloid
  include CurrentLeader
  include Logging

  def initialize(perform = true)
    async.perform if perform
  end

  def perform
    info 'starting to cleanup stale containers'
    loop do
      sleep 1.minute.to_i
      if leader?
        destroy_deleted_containers
        terminate_ghost_containers
      end
    end
  end

  def destroy_deleted_containers
    Container.deleted.where(:deleted_at.lt => 1.minutes.ago).each do |c|
      c.destroy
    end
  end

  def terminate_ghost_containers
    Container.unscoped.where(:grid_service_id.ne => nil).each do |c|
      if c.grid_service.nil?
        terminate_ghost_container(c)
      end
    end
  end

  # @param [Docker::Container] container
  def terminate_ghost_container(container)
    if container.host_node
      info "terminating #{container.to_path}"

      cleanup_lb = true
      stack_name = container.label('io.kontena.stack.name') || Stack::NULL_STACK
      stack = container.host_node.grid.stacks.find_by(name: stack_name)
      if stack
        service_name = container.label('io.kontena.service.name')
        replaced_service = stack.grid_services.find_by(name: service_name)
        cleanup_lb = false if replaced_service
      end

      terminator = service_terminator(container.host_node)
      terminator.request_terminate_service(
        container.grid_service_id.to_s, container.instance_number, {lb: cleanup_lb}
      )
    else
      info "removing #{container.to_path} because host node not found"
      container.destroy
    end
  rescue => exc
    error "#{exc.class.name}: #{exc.message}"
  end

  def service_terminator(node)
    Docker::ServiceTerminator.new(node)
  end
end
