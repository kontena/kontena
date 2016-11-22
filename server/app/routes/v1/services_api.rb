module V1
  class ServicesApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor
    include LogsHelpers

    plugin :multi_route
    plugin :streaming

    require_glob File.join(__dir__, '/services/*.rb')

    route do |r|
      validate_access_token
      require_current_user

      # /v1/services/:grid_name
      r.on ':grid_name' do |grid_name|
        unless @grid = Grid.find_by(name: grid_name)
          halt_request(404, {error: 'Not found'})
        end

        r.on ':name' do |name|
          if @stack = @grid.stacks.find_by(name: name)
            r.on ':service_name' do |service_name|
              unless @grid_service = @stack.grid_services.find_by(name: service_name)
                halt_request(404, {error: 'Not found'})
              end

              r.route 'service'
            end
          elsif @grid_service = @grid.grid_services.find_by(name: name)
            r.route 'service'
          else
            halt_request(404, {error: 'Not found'})
          end
        end
      end
    end

    route('service') do |r|
      unless current_user.grid_ids.include?(@grid_service.grid_id)
        halt_request(403, {error: 'Access denied'})
      end

      # /v1/services/:grid_name/:stack_name/:service_name/containers
      r.on 'containers' do
        r.route 'service_containers'
      end

      # /v1/services/:grid_name/:stack_name/:service_name/stats
      r.on 'stats' do
        r.route 'service_stats'
      end

      # /v1/services/:grid_name/:stack_name/:service_name/envs
      r.on 'envs' do
        r.route 'service_envs'
      end

      # /v1/services/:grid_name/:stack_name/:service_name/container_logs
      r.on 'container_logs' do
        r.route 'service_container_logs'
      end

      # /v1/services/:grid_name/:stack_name/:service_name/deploys
      r.on 'deploys' do
        r.route 'service_deploys'
      end

      # GET /v1/services/:grid_name/:stack_name/:service_name
      r.get do
        r.is do
          render('grid_services/show')
        end
      end

      # POST /v1/services/:grid_name/:stack_name/:service_name
      r.post do
        # POST /v1/services/:grid_name/:stack_name/:service_name/deploy
        r.on('deploy') do
          data = parse_json_body rescue {}
          data[:grid_service] = @grid_service
          outcome = GridServices::Deploy.run(data)
          if outcome.success?
            audit_event(r, @grid_service.grid, @grid_service, 'deploy', @grid_service)
            @grid_service_deploy = outcome.result
            render('grid_service_deploys/show')
          else
            halt_request(422, { error: outcome.errors.message })
          end
        end

        # POST /v1/services/:grid_name/:stack_name/:service_name/scale
        r.on('scale') do
          data = parse_json_body
          outcome = GridServices::Scale.run(
              grid_service: @grid_service,
              instances: data['instances']
          )
          if outcome.success?
            audit_event(r, @grid_service.grid, @grid_service, 'scale', @grid_service)
            @grid_service_deploy = outcome.result
            render('grid_service_deploys/show')
          else
            halt_request(422, { error: outcome.errors.message })
          end
        end

        # POST /v1/services/:grid_name/:stack_name/:service_name/restart
        r.on('restart') do
          outcome = GridServices::Restart.run(
              grid_service: @grid_service
          )
          if outcome.success?
            audit_event(r, @grid_service.grid, @grid_service, 'restart', @grid_service)
            {}
          else
            halt_request(422, { error: outcome.errors.message })
          end
        end

        # POST /v1/services/:grid_name/:stack_name/:service_name/stop
        r.on('stop') do
          outcome = GridServices::Stop.run(
              grid_service: @grid_service
          )
          if outcome.success?
            audit_event(r, @grid_service.grid, @grid_service, 'stop', @grid_service)
            {}
          else
            halt_request(422, { error: outcome.errors.message })
          end
        end

        # POST /v1/services/:grid_name/:stack_name/:service_name/start
        r.on('start') do
          outcome = GridServices::Start.run(
              grid_service: @grid_service
          )
          if outcome.success?
            audit_event(r, @grid_service.grid, @grid_service, 'start', @grid_service)
            {}
          else
            halt_request(422, { error: outcome.errors.message })
          end
        end

        # POST /v1/services/:grid_name/:stack_name/:service_name/exec
        r.on 'exec' do
          data = parse_json_body
          container = @grid_service.containers.where(name: "#{@grid_service.name}-#{data['instance']}")
          halt_request(404) unless container
          Docker::ContainerExecutor.new(container).exec_in_container(data['cmd'])
        end
      end

      # PUT /v1/services/:grid_name/:stack_name/:service_name
      r.put do
        data = parse_json_body
        data[:grid_service] = @grid_service
        outcome = GridServices::Update.run(data)
        if outcome.success?
          @grid_service = outcome.result
          audit_event(r, @grid_service.grid, @grid_service, 'update', @grid_service)
          render('grid_services/show')
        else
          halt_request(422, { error: outcome.errors.message })
        end
      end

      # DELETE /v1/services/:grid_name/:stack_name/:service_name
      r.delete do
        r.is do
          outcome = GridServices::Delete.run(
              grid_service: @grid_service
          )
          if outcome.success?
            audit_event(r, @grid_service.grid, @grid_service, 'delete', @grid_service)
            {}
          else
            halt_request(422, { error: outcome.errors.message })
          end
        end
      end
    end
  end
end
