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
      @grid_services = @grid.grid_services.visible
      render('grid_services/index')
    end
  end
end
