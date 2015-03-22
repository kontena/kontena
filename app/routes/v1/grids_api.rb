require_relative '../../mutations/grids/create'
require_relative '../../mutations/grids/update'

module V1
  class GridsApi < Roda
    include OAuth2TokenVerifier
    include CurrentUser
    include RequestHelpers
    include Auditor

    plugin :all_verbs
    plugin :json
    plugin :render, engine: 'jbuilder', ext: 'json.jbuilder', views: 'app/views/v1'
    plugin :multi_route
    plugin :error_handler do |e|
      response.status = 500
      log_message = "\n#{e.class} (#{e.message}):\n"
      log_message << "  " << e.backtrace.join("\n  ") << "\n\n"
      request.logger.error log_message
      { message: 'Internal server error' }
    end

    Dir[File.join(__dir__, '/grids/*.rb')].each{|f| require f}

    route do |r|

      validate_access_token
      require_current_user

      ##
      # @param [String] id
      # @return [Grid]
      def load_grid(id)
        @grid = current_user.grids.find_by(id: id)
        if !@grid
          halt_request(404, {error: 'Not found'})
        end
      end

      r.on ':id/services' do |id|
        load_grid(id)
        r.route 'grid_services'
      end

      r.on ':id/nodes' do |id|
        load_grid(id)
        r.route 'grid_nodes'
      end

      r.on ':id/stats' do |id|
        load_grid(id)
        r.route 'grid_stats'
      end

      r.on ':id/users' do |id|
        load_grid(id)
        r.route 'grid_users'
      end

      r.post do
        r.is do
          data = parse_json_body
          outcome = Grids::Create.run(
              user: current_user,
              name: data['name']
          )

          if outcome.success?
            @grid = outcome.result
            audit_event(r, @grid, @grid, 'create')
            response.status = 201
            render('grids/show')
          else
            response.status = 422
            {error: outcome.errors.message}
          end
        end
      end

      r.get do

        # GET /v1/grids
        r.is do
          @grids = current_user.grids
          render('grids/index')
        end

        # GET /v1/grids/:id
        r.on ':id' do |id|
          load_grid(id)
          r.is do
            render('grids/show')
          end

          r.on 'container_logs' do
            @logs = @grid.container_logs.order(created_at: :desc).limit(500).to_a.reverse
            render('container_logs/index')
          end

          r.on 'audit_log' do
            limit = request.params['limit'] || 500
            @logs = @grid.audit_logs.order(created_at: :desc).limit(limit).to_a.reverse
            render('audit_logs/index')
          end
        end
      end

      r.put do
        r.on ':id' do |id|
          load_grid(id)

          # PUT /v1/grids/:id
          r.is do
            data = parse_json_body
            outcome = Grids::Update.run(
                grid: @grid,
                name: data['name']
            )
            if outcome.success?
              @grid = outcome.result
              audit_event(r, @grid, @grid, 'update')
              response.status = 200
              render('grids/show')
            else
              response.status = 422
              {error: outcome.errors.message}
            end
          end
        end
      end

      r.delete do
        r.on ':id' do |id|
          load_grid(id)

          # DELETE /v1/grids/:id
          r.is do
            outcome = Grids::Delete.run({grid: @grid})
            if outcome.success?
              audit_event(r, @grid, @grid, 'delete')
              response.status = 200
              {}
            else
              response.status = 422
              {error: outcome.errors.message}
            end
          end
        end
      end
    end
  end
end
