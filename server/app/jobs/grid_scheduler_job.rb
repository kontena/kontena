require_relative '../services/logging'

class GridSchedulerJob
  include Celluloid
  include Logging
  include CurrentLeader

  def initialize
    async.perform
  end

  # @param [Grid] grid
  def reschedule_grid(grid)
    info "rescheduling #{grid.name} services"
    schedule_grid(grid) # XXX: if leader?
  end

  def perform
    info 'starting to watch services'
    every(20) do
      if leader?
        schedule_grids
      end
    end
  end

  def schedule_grids
    Grid.all.each do |grid|
      schedule_grid(grid)
    end
  end

  # @param [Grid] grid
  def schedule_grid(grid)
    scheduler = GridScheduler.new(grid)
    grid.grid_services.order(updated_at: :asc).each do |service|
      begin
        scheduler.check_service(service)
      rescue => exc
        error "error occurred in service #{service.to_path}"
        error exc.message
      end
    end
  end
end
