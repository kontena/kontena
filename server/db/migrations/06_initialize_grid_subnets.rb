class InitializeGridSubnets < Mongodb::Migration

  def self.up
    OverlayCidr.create_indexes

    Grid.each do |grid|
      grid.overlay_cidrs.each do |c|
        c.set(:reserved_at => c.created_at)
      end
      allocator = Docker::OverlayCidrAllocator.new(grid)
      allocator.initialize_grid_subnet
    end
  end
end
