require_relative '../../../mutations/host_nodes/remove'
require_relative '../../../services/event_stream/grid_event_notifier'

V1::GridsApi.route('grid_nodes') do |r|

  # GET /v1/grids/:id/nodes
  r.get do
    r.is do
      @nodes = @grid.host_nodes.order(name: :asc)
      HostNodeSerializer.new(@nodes).to_json(root: :nodes)
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
        audit_event(r, @grid, node, 'remove node')
        HostNodes::Remove.run(host_node: node)
        response.status = 200
        {}
      else
        response.status = 404
      end
    end
  end
end
