

V1::GridsApi.route('external_registries') do |r|

  # GET /v1/grids/:id/external_registries
  r.get do
    r.is do
      @registries = @grid.registries
      render('registries/index')
    end
  end

  # POST /v1/grids/:id/external_registries
  r.post do
    r.is do
      data = parse_json_body
      outcome = Registries::Create.run(
          grid: @grid,
          url: data['url'],
          username: data['username'],
          password: data['password'],
          email: data['email']
      )
      if outcome.success?
        @registry = outcome.result
        response.status = 201
        render('registries/show')
      else
        response.status = 422
        outcome.errors.message
      end
    end
  end

  r.delete do
    r.on(':name') do |name|
      registry = @grid.registries.find_by(name: name)
      if registry
        registry.destroy
        response.status = 200
      else
        response.status = 400
      end
    end
  end
end
