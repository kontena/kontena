require_relative '../../mutations/grids/create'
require_relative '../../mutations/grids/update'
require_relative '../../services/event_stream/grid_event_server'
require_relative '../../services/event_stream/grid_event_notifier'

module V1
  class GridsApi < Roda
    include OAuth2TokenVerifier
    include CurrentUser
    include RequestHelpers
    include Auditor
    include EventStream::GridEventNotifier

    plugin :multi_route
    plugin :streaming
    plugin :websockets, :ping => 45

    Dir[File.join(__dir__, '/grids/*.rb')].each{|f| require f}

    def validate_access_token
      if request.params['token']
        validate_ws_access_token(request.params['token'])
      else
        super
      end
    end

    def validate_ws_access_token(token)
      access_token = AccessToken.find_by(token: token)
      unless access_token
        halt_request(403, {error: 'Access denied'})
        return
      end
      @current_user_id = access_token.user_id
    end

    route do |r|

      validate_access_token
      require_current_user

      ##
      # @param [String] name
      # @return [Grid]
      def load_grid(name)
        @grid = current_user.grids.find_by(name: name)
        if !@grid
          halt_request(404, {error: 'Not found'})
        end
      end

      r.on ':name/services' do |name|
        load_grid(name)
        r.route 'grid_services'
      end

      r.on ':name/nodes' do |name|
        load_grid(name)
        r.route 'grid_nodes'
      end

      r.on ':name/stats' do |name|
        load_grid(name)
        r.route 'grid_stats'
      end

      r.on ':name/users' do |name|
        load_grid(name)
        r.route 'grid_users'
      end

      # /v1/grids/:name/external_registries
      r.on ':name/external_registries' do |name|
        load_grid(name)
        r.route 'external_registries'
      end

      # /v1/grids/:name/container_logs
      r.on ':name/container_logs' do |name|
        load_grid(name)
        r.route 'grid_container_logs'
      end

      r.post do
        r.is do
          data = parse_json_body
          outcome = Grids::Create.run(
              user: current_user,
              name: data['name'],
              initial_size: data['initial_size'] || 1
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
          GridSerializer.new(@grids).to_json(root: :grids)
        end

        # GET /v1/grids/:name
        r.on ':name' do |name|
          load_grid(name)
          r.is do
            GridSerializer.new(@grid).to_json
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

          r.on 'events' do
            r.websocket do |ws|
              EventStream::GridEventServer.serve(ws, @grid, r.params)
            end

            @access_token = AccessTokens::Create.run(
                user: current_user,
                scopes: ['user'],
                type: 'ws'
            ).result
            render('auth/show')
          end
        end
      end

      r.put do
        r.on ':name' do |name|
          load_grid(name)

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
        r.on ':name' do |name|
          load_grid(name)

          # DELETE /v1/grids/:name
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
