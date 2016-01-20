class GridSchedulerWorker
  include Celluloid

  def perform(grid_id)
    grid = Grid.find_by(id: grid_id)
    if grid
      reschedule(grid)
    end
  end

  def later(sec, grid_id)
    after(sec) { perform(grid_id) }
  end

  private

  def reschedule(grid)
    GridScheduler.new(grid).reschedule
  end
end