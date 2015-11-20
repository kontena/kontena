require_relative 'grid_service_deployer'
require_relative '../mutations/grid_services/deploy'
require_relative 'logging'

class GridScheduler
  include Logging
  attr_reader :grid

  # @param [Grid] grid
  def initialize(grid)
    @grid = grid
  end

  # @return [Celluloid::Future]
  def reschedule
    Celluloid::Future.new {
      self.reschedule_services
    }
  end

  def reschedule_services
    grid.grid_services.each do |service|
      if can_reschedule_service?(service)
        reschedule_stateless_service(service)
      end
    end
  rescue => exc
    error exc.message
    debug exc.backtrace.join("\n") if exc.backtrace
  end

  # @param [GridService] service
  # @return [Boolean]
  def can_reschedule_service?(service)
    service.stateless? && !service.deploying? && !service.dependant_services?
  end

  # @param [GridService] service
  def reschedule_stateless_service(service)
    if should_reschedule_service?(service)
      GridServices::Deploy.run(
        grid_service: service,
        strategy: service.strategy
      )
    else
      info "seems that re-scheduling does not change anything for #{service.to_path}... aborting"
    end
  end

  # @param [GridService] service
  # @return [Boolean]
  def should_reschedule_service?(service)
    current_nodes = service.containers.map{|c| c.host_node}.delete_if{|n| n.nil?}.uniq.sort
    available_nodes = service.grid.host_nodes.connected.to_a
    service_deployer = GridServiceDeployer.new(
      self.strategy(service.strategy), service, available_nodes
    )
    if service_deployer.instance_count != service.containers.count
      return true
    end

    selected_nodes = service_deployer.selected_nodes.uniq.sort
    selected_nodes != current_nodes
  end

  # @param [String] name
  def strategy(name)
    GridServiceScheduler::STRATEGIES[name].new
  end
end
