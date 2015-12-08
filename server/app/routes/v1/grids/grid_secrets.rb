require_relative '../../../mutations/grid_secrets/create'

V1::GridsApi.route('grid_secrets') do |r|

  # POST /v1/grids/:name/services
  r.post do
    data = parse_json_body
    data[:grid] = @grid
    outcome = GridSecrets::Create.run(data)
    if outcome.success?
      response.status = 201
      @grid_secret = outcome.result
      audit_event(r, @grid, @grid_secret, 'create')
      render('grid_secrets/show')
    else
      response.status = 422
      {error: outcome.errors.message}
    end
  end

  # GET /v1/grids/:name/services
  r.get do
    r.is do
      @grid_secrets = @grid.grid_secrets.visible
      render('grid_secrets/index')
    end
  end
end
