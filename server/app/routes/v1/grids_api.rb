require_relative '../../mutations/grids/create'
require_relative '../../mutations/grids/update'

module V1
  class GridsApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor
    include LogsHelpers

    plugin :multi_route
    plugin :streaming

    require_glob File.join(__dir__, '/grids/*.rb')

    route do |r|

      validate_access_token
      require_current_user

      ##
      # @param [String] name
      # @return [Grid]
      def load_grid(name)
        @grid = current_user.accessible_grids.find_by(name: name)
        halt_request(404, {error: 'Not found'}) unless @grid
      end

      r.on ':name/stacks' do |name|
        load_grid(name)
        r.route 'grid_stacks'
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

      # /v1/grids/:name/secrets
      r.on ':name/secrets' do |name|
        load_grid(name)
        r.route 'grid_secrets'
      end

      r.post do
        r.is do
          data = parse_json_body
          outcome = Grids::Create.run(
              user: current_user,
              name: data['name'],
              initial_size: data['initial_size'] || 1,
              token: data['token'],
              subnet: data['subnet'],
              supernet: data['supernet'],
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
          @grids = current_user.accessible_grids
          render('grids/index')
        end

        # GET /v1/grids/:name
        r.on ':name' do |name|
          load_grid(name)
          r.is do
            render('grids/show')
          end

          r.on 'container_logs' do
            scope = @grid.container_logs

            unless r['containers'].nil?
              container_names = r['containers'].split(',')

              scope = scope.where(name: {:$in => container_names})
            end

            unless r['nodes'].nil?
              nodes = r['nodes'].split(',').map do |name|
                @grid.host_nodes.find_by(name: name).try(:id)
              end.delete_if{|n| n.nil?}

              scope = scope.where(host_node_id: {:$in => nodes})
            end
            unless r['services'].nil?
              services = r['services'].split(',').map do |service|
                @grid.grid_services.find_by(name: service).try(:id)
              end.delete_if{|s| s.nil?}

              scope = scope.where(grid_service_id: {:$in => services})
            end

            render_container_logs(r, scope)
          end

          r.on 'audit_log' do
            limit = (1..3000).cover?(request.params['limit'].to_i) ? request.params['limit'].to_i : 500
            @logs = @grid.audit_logs.order(created_at: :desc).limit(limit).to_a.reverse
            render('audit_logs/index')
          end
        end
      end

      r.put do
        r.on ':name' do |name|
          load_grid(name)

          # PUT /v1/grids/:id
          r.is do
            data = parse_json_body
            data[:grid] = @grid
            data[:user] = current_user
            outcome = Grids::Update.run(data)
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
            outcome = Grids::Delete.run({user: current_user, grid: @grid})
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
