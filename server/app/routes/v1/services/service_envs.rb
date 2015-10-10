V1::ServicesApi.route('service_envs') do |r|

  # GET /v1/services/:grid_name/:service_name/envs
  r.post do
    r.is do
      data = parse_json_body
      outcome = GridServices::AddEnv.run(
        grid_service: @grid_service,
        env: data['env']
      )
      if outcome.success?
        audit_event(r, @grid_service.grid, @grid_service, 'add_env', @grid_service)
        {}
      else
        response.status = 422
        outcome.errors.message
      end
    end
  end

  r.delete do
    r.on ':env' do |env|
      outcome = GridServices::RemoveEnv.run(
        grid_service: @grid_service,
        env: env
      )
      if outcome.success?
        audit_event(r, @grid_service.grid, @grid_service, 'remove_env', @grid_service)
        {}
      else
        response.status = 422
        outcome.errors.message
      end
    end
  end
end
