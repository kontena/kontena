V1::GridsApi.route('grid_nodes') do |r|

  # GET /v1/grids/:id/nodes
  r.get do
    r.is do
      @nodes = @grid.host_nodes.order(name: :asc)
      render('host_nodes/index')
    end

    r.on ':id' do |id|
      @node = @grid.host_nodes.find_by(name: id)
      if @node
        render('host_nodes/show')
      else
        response.status = 404
      end
    end
  end

  r.delete do
    r.on ':id' do |id|
      node = @grid.host_nodes.find_by(name: id)
      if node
        node.destroy
        response.status = 200
        {}
      else
        response.status = 404
      end
    end
  end
end
