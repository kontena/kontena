require_relative '../../../mutations/grid_secrets/create'

V1::GridsApi.route('grid_secrets') do |r|

  unless SymmetricEncryption.cipher?
    halt_request(503, {error: 'Vault not configured'})
  end

  # POST /v1/grids/:grid/secrets
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

  r.put do
    # PUT /v1/grids/:grid/secrets/:name
    r.on ':name' do |name|
      secret = @grid.grid_secrets.find_by(name: name)
      if secret
        data = parse_json_body
        outcome = GridSecrets::Update.run(
          grid_secret: secret,
          value: data['value']
        )
        if outcome.success?
          audit_event(r, @grid, secret, 'update secret')
          response.status = 200
          @grid_secret = outcome.result
          render('grid_secrets/show')
        else
          response.status = 422
          {error: outcome.errors.message}
        end
      else
        response.status = 404
      end
    end
  end

  # GET /v1/grids/:grid/secrets
  r.get do
    r.is do
      @grid_secrets = @grid.grid_secrets
      render('grid_secrets/index')
    end
  end
end
