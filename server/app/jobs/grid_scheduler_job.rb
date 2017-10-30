require_relative '../services/logging'

class GridSchedulerJob
  include Celluloid
  include Logging
  include CurrentLeader
  include Workers

  def initialize(perform = true)
    async.perform if perform
  end

  def perform
    info 'starting to watch services'
    loop do
      sleep 20
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
    grid.grid_services.order(updated_at: :asc).pluck(:id).each do |service_id|
      service = GridService.find(service_id)
      if service && leader?
        begin
          ts = Time.now
          Mongoid::QueryCache.cache {
            scheduler.check_service(service)
            took = Time.now - ts
            warn "calculating state of service #{service.to_path} took #{took.to_f} seconds" if took.to_f > 0.5
          }
          sleep 0.1
        rescue => exc
          error "error occurred in service #{service.to_path}"
          error exc.message
        ensure
          Mongoid::QueryCache.clear_cache
        end
      else
        info "skipping checks because not a leader anymore"
      end
    end
  end
end
