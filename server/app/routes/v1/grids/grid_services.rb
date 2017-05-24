require_relative '../../../mutations/grid_services/create'

V1::GridsApi.route('grid_services') do |r|

  # POST /v1/grids/:name/services
  r.post do
    data = parse_json_body
    data[:current_user] = current_user
    data[:grid] = @grid
    outcome = GridServices::Create.run(data)
    if outcome.success?
      response.status = 201
      @grid_service = outcome.result
      audit_event(r, @grid, @grid_service, 'create', @grid_service)
      render('grid_services/show')
    else
      response.status = 422
      {error: outcome.errors.message}
    end
  end

  # GET /v1/grids/:name/services
  r.get do
    r.is do
      query = @grid.grid_services.includes(:grid, :stack).order_by(:_id.desc)
      unless r['stack'].to_s.empty?
        stack = @grid.stacks.find_by(name: r['stack'])
        halt_request(404, {error: 'Stack not found'}) unless stack

        query = query.where(stack_id: stack.id)
      end
      @grid_services = query.to_a
      render('grid_services/index')
    end
  end
end
