
# Route: /v1/grids/:id/external_registries
V1::GridsApi.route('external_registries') do |r|

  # GET
  r.get do
    r.is do
      @registries = @grid.registries
      render('external_registries/index')
    end
  end

  # POST
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
        render('external_registries/show')
      else
        halt_request(422, { error: outcome.errors.message })
      end
    end
  end
end
