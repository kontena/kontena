

V1::UserApi.route('registries') do |r|

  # GET /v1/user/:id/registries
  r.get do
    r.is do
      @registries = current_user.registries
      render('registries/index')
    end
  end

  # POST /v1/user/:id/registries
  r.post do
    r.is do
      data = parse_json_body
      outcome = Registries::Create.run(
          user: current_user,
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
end
