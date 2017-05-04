V1::GridsApi.route('grid_nodes') do |r|

  # GET /v1/grids/:id/nodes
  r.get do
    r.is do
      @nodes = @grid.host_nodes.includes(:grid).order(name: :asc)
      render('host_nodes/index')
    end
  end
end
