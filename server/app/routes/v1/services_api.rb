module V1
  class ServicesApi < Roda
    include OAuth2TokenVerifier
    include CurrentUser
    include RequestHelpers
    include Auditor
    include LogsHelpers

    plugin :multi_route
    plugin :streaming

    Dir[File.join(__dir__, '/services/*.rb')].each{|f| require f}

    route do |r|

      validate_access_token
      require_current_user

      def load_grid_service(grid_name, service_name)
        grid = Grid.find_by(name: grid_name)
        halt_request(404, {error: 'Not found'}) if !grid
        grid_service = grid.grid_services.find_by(name: service_name)
        halt_request(404, {error: 'Not found'}) if !grid_service

        unless current_user.grid_ids.include?(grid_service.grid_id)
          halt_request(403, {error: 'Access denied'})
        end

        grid_service
      end

      # /v1/services/:grid_name/:service_name/containers
      r.on ':grid_name/:service_name/containers' do |grid_name, service_name|
        @grid_service = load_grid_service(grid_name, service_name)
        r.route 'service_containers'
      end

      # /v1/services/:grid_name/:service_name/stats
      r.on ':grid_name/:service_name/stats' do |grid_name, service_name|
        @grid_service = load_grid_service(grid_name, service_name)
        r.route 'service_stats'
      end

      # /v1/services/:grid_name/:service_name/envs
      r.on ':grid_name/:service_name/envs' do |grid_name, service_name|
        @grid_service = load_grid_service(grid_name, service_name)
        r.route 'service_envs'
      end

      # /v1/services/:grid_name/:service_name
      r.on ':grid_name/:service_name' do |grid_name, service_name|
        @grid_service = load_grid_service(grid_name, service_name)

        # GET /v1/services/:grid_name/:service_name
        r.get do
          r.is do
            render('grid_services/show')
          end

          r.on 'container_logs' do
            scope = @grid_service.container_logs

            scope = scope.where(name: r['container']) unless r['container'].nil?
            scope = scope.where(:$text => {:$search => r['search']}) unless r['search'].nil?

            render_container_logs(r, scope)
          end
        end

        # POST /v1/services/:grid_name/:service_name
        r.post do
          r.on('deploy') do
            data = parse_json_body rescue {}
            data[:current_user] = current_user
            data[:grid_service] = @grid_service
            outcome = GridServices::Deploy.run(data)
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'deploy', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          r.on('scale') do
            data = parse_json_body
            outcome = GridServices::Scale.run(
                current_user: current_user,
                grid_service: @grid_service,
                instances: data['instances']
            )
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'scale', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          r.on('restart') do
            outcome = GridServices::Restart.run(
                current_user: current_user,
                grid_service: @grid_service
            )
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'restart', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          r.on('stop') do
            outcome = GridServices::Stop.run(
                current_user: current_user,
                grid_service: @grid_service
            )
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'stop', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          r.on('start') do
            outcome = GridServices::Start.run(
                current_user: current_user,
                grid_service: @grid_service
            )
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'start', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end
        end

        # PUT /v1/services/:grid_name/:service_name
        r.put do
          data = parse_json_body
          data[:current_user] = current_user
          data[:grid_service] = @grid_service
          outcome = GridServices::Update.run(data)
          if outcome.success?
            @grid_service = outcome.result
            audit_event(r, @grid_service.grid, @grid_service, 'update', @grid_service)
            render('grid_services/show')
          else
            response.status = 422
            outcome.errors.message
          end
        end

        # DELETE /v1/services/:grid_name/:service_name
        r.delete do
          r.is do
            outcome = GridServices::Delete.run(
                current_user: current_user,
                grid_service: @grid_service
            )
            if outcome.success?
              audit_event(r, @grid_service.grid, @grid_service, 'delete', @grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end
        end
      end
    end
  end
end
