require_relative '../../../mutations/grid_secrets/create'

V1::GridsApi.route('grid_secrets') do |r|

  unless SymmetricEncryption.cipher?
    halt_request(503, {error: 'Vault not configured'})
  end

  def create_secret(data)
    data[:grid] = @grid
    outcome = GridSecrets::Create.run(data)

    if outcome.success?
      @grid_secret = outcome.result
      audit_event(request, @grid, @grid_secret, 'create', nil, [:body])
      response.status = 201
      render('grid_secrets/show')
    else
      response.status = 422
      {error: outcome.errors.message}
    end
  end

  def update_secret(secret, value)
    outcome = GridSecrets::Update.run(
      grid_secret: secret,
      value: value
    )

    if outcome.success?
      @grid_secret = outcome.result
      audit_event(request, @grid, @grid_secret, 'update', nil, [:body])
      response.status = 200
      render('grid_secrets/show')
    else
      response.status = 422
      {error: outcome.errors.message}
    end
  end

  # POST /v1/grids/:grid/secrets
  r.post do
    data = parse_json_body
    create_secret(data)
  end

  # @todo: deprecated
  r.put do
    # PUT /v1/grids/:grid/secrets/:name
    r.on ':name' do |name|
      secret = @grid.grid_secrets.find_by(name: name)
      data = parse_json_body

      if secret
        update_secret(secret, data['value'])
      elsif data['upsert']
        create_secret(data)
      else
        response.status = 404
      end
    end
  end

  # GET /v1/grids/:grid/secrets
  r.get do
    r.is do
      @grid_services = @grid.grid_services.where(:secrets.exists => true)
      @grid_secrets = @grid.grid_secrets.includes(:grid)
      render('grid_secrets/index')
    end
  end
end
