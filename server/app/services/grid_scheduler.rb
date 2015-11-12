require_relative 'grid_service_deployer'
require_relative '../mutations/grid_services/deploy'

class GridScheduler

  attr_reader :grid

  # @param [Grid] grid
  def initialize(grid)
    @grid = grid
  end

  def reschedule
    Celluloid::Future.new {
      self.reschedule_services
    }
  end

  def reschedule_services
    grid.grid_services.each do |service|
      if service.stateless? && !service.deploying?
        reschedule_stateless_service(service)
      elsif service.stateful? && !service.deploying?
        reschedule_stateful_service(service)
      end
    end
  end

  def reschedule_stateless_service(service)
    GridServices::Deploy.run(
      grid_service: service,
      strategy: service.strategy
    )
  end

  def reschedule_stateful_service(service)
    GridServices::Deploy.run(
      grid_service: service,
      strategy: service.strategy
    )
  end
end
