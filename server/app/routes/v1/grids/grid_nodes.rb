V1::GridsApi.route('grid_nodes') do |r|

  # GET /v1/grids/:id/nodes
  r.get do
    r.is do
      @nodes = @grid.host_nodes.includes(:grid).order(name: :asc)
      render('host_nodes/index')
    end
  end

  r.post do
    halt_request(403, {error: 'Access denied'}) unless current_user.can_update?(@grid)

    r.is do
      data = parse_json_body
      params = { grid: @grid }
      params[:name] = data['name']
      params[:token] = data['token'] if data['token']
      params[:labels] = data['labels'] if data['labels']
      outcome = HostNodes::Create.run(params)
      if outcome.success?
        @node = outcome.result
        response.status = 201
        render('host_nodes/show')
      else
        halt_request(422, {error: outcome.errors.message})
      end
    end
  end
end
