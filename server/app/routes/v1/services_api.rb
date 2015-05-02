module V1
  class ServicesApi < Roda
    include OAuth2TokenVerifier
    include CurrentUser
    include RequestHelpers
    include Auditor

    plugin :multi_route


    Dir[File.join(__dir__, '/services/*.rb')].each{|f| require f}

    route do |r|

      validate_access_token
      require_current_user

      def load_grid_service(id)
        @grid_service = GridService.find_by(name: id)
        if !@grid_service
          halt_request(404, {error: 'Not found'})
        end
        unless current_user.grid_ids.include?(@grid_service.grid_id)
          halt_request(403, {error: 'Access denied'})
        end
      end

      # /v1/services/:id/containers
      r.on ':id/containers' do |id|
        load_grid_service(id)
        r.route 'service_containers'
      end

      # /v1/services/:id/stats
      r.on ':id/stats' do |id|
        load_grid_service(id)
        r.route 'service_stats'
      end

      # /v1/services/:id
      r.on ':id' do |id|
        grid_service = GridService.find_by(name: id)
        if !grid_service
          halt_request(404, {error: "Not found: #{id}"}) and return
        end
        unless current_user.grid_ids.include?(grid_service.grid_id)
          halt_request(403, {error: 'Access denied'}) and return
        end

        # GET /v1/services/:id
        r.get do
          r.is do
            @grid_service = grid_service
            render('grid_services/show')
          end

          r.on 'container_logs' do
            scope = grid_service.container_logs
            limit = (r['limit'] || 500).to_i
            unless r['from'].nil?
              scope = scope.where(:id.gt => r['from'] )
            end
            @logs = scope.order(:$natural => -1).limit(limit).to_a.reverse
            render('container_logs/index')
          end
        end

        # POST /v1/services/:id
        r.post do
          r.on('deploy') do
            data = parse_json_body rescue {}
            data[:current_user] = current_user
            data[:grid_service] = grid_service
            outcome = GridServices::Deploy.run(data)
            if outcome.success?
              audit_event(r, grid_service.grid, grid_service, 'deploy', grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          r.on('restart') do
            outcome = GridServices::Restart.run(
                current_user: current_user,
                grid_service: grid_service
            )
            if outcome.success?
              audit_event(r, grid_service.grid, grid_service, 'restart', grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          r.on('stop') do
            outcome = GridServices::Stop.run(
                current_user: current_user,
                grid_service: grid_service
            )
            if outcome.success?
              audit_event(r, grid_service.grid, grid_service, 'stop', grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end

          r.on('start') do
            outcome = GridServices::Start.run(
                current_user: current_user,
                grid_service: grid_service
            )
            if outcome.success?
              audit_event(r, grid_service.grid, grid_service, 'start', grid_service)
              {}
            else
              response.status = 422
              outcome.errors.message
            end
          end
        end

        # PUT /v1/services/:id
        r.put do
          data = parse_json_body
          data[:current_user] = current_user
          data[:grid_service] = grid_service
          outcome = GridServices::Update.run(data)
          if outcome.success?
            @grid_service = outcome.result
            audit_event(r, grid_service.grid, grid_service, 'update', grid_service)
            render('grid_services/show')
          else
            response.status = 422
            outcome.errors.message
          end
        end

        # DELETE /v1/services/:id
        r.delete do
          r.is do
            outcome = GridServices::Delete.run(
                current_user: current_user,
                grid_service: grid_service
            )
            if outcome.success?
              audit_event(r, grid_service.grid, grid_service, 'delete', grid_service)
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
