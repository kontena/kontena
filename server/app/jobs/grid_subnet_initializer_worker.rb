class GridSubnetInitializerWorker
  include Celluloid

  def perform(grid_id)
    grid = Grid.find_by(id: grid_id)
    if grid
      overlay_allocator = Docker::OverlayCidrAllocator.new(grid)
      overlay_allocator.initialize_grid_subnet
    end
  end
end