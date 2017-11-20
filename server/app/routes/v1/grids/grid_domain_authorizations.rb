require_relative '../../../mutations/grid_services/create'

V1::GridsApi.route('grid_domain_authorizations') do |r|

  # POST /v1/grids/:name/domain_authorizations
  r.post do
    data = parse_json_body
    data[:grid] = @grid
    outcome = GridDomainAuthorizations::Authorize.run(data)
    if outcome.success?
      response.status = 201
      @domain_authorization = outcome.result
      audit_event(r, @grid, @domain_authorization, 'create', @domain_authorization)
      render('domain_authorizations/show')
    else
      response.status = 422
      {error: outcome.errors.message}
    end
  end

  # GET /v1/grids/:name/domain_authorizations
  r.get do
    r.is do
      @domain_authorizations = @grid.grid_domain_authorizations
      render('domain_authorizations/index')
    end
  end

end
