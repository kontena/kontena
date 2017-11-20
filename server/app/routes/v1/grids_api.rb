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

      r.is do
        r.get do
          @grids = current_user.accessible_grids
          render('grids/index')
        end

        r.post do
          data = parse_json_body
          outcome = Grids::Create.run(
              user: current_user,
              name: data['name'],
              initial_size: data['initial_size'] || 1,
              token: data['token'],
              subnet: data['subnet'],
              supernet: data['supernet'],
              default_affinity: data['default_affinity'],
              trusted_subnets: data['trusted_subnets'],
              stats: data['stats'],
              logs: data['logs'],
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

      r.on ':name' do |name|
        load_grid(name)

        # /v1/grids/:name/stacks
        r.on 'stacks' do
          r.route 'grid_stacks'
        end

        # /v1/grids/:name/services
        r.on 'services' do
          r.route 'grid_services'
        end

        # /v1/grids/:name/nodes
        r.on 'nodes' do
          r.route 'grid_nodes'
        end

        # /v1/grids/:name/stats
        r.on 'stats' do
          r.route 'grid_stats'
        end

        r.on 'metrics' do
          load_grid(name)
          r.route 'grid_metrics'
        end

        # /v1/grids/:name/users
        r.on 'users' do
          r.route 'grid_users'
        end

        # /v1/grids/:name/external_registries
        r.on 'external_registries' do
          r.route 'external_registries'
        end

        # /v1/grids/:name/secrets
        r.on 'secrets' do
          r.route 'grid_secrets'
        end

        # /v1/grids/:name/event_logs
        r.on 'event_logs' do
          r.route 'grid_event_logs'
        end

        # /v1/grids/:name/domain_authorizations
        r.on 'domain_authorizations' do
          r.route 'grid_domain_authorizations'
        end

        # /v1/grids/:name/certificates
        r.on 'certificates' do
          r.route 'grid_certificates'
        end

        r.get do
          r.is do
            render('grids/show')
          end

          r.on 'container_logs' do
            scope = @grid.container_logs.includes(
              :host_node, :grid, :grid_service
            ).with(
              read: { mode: :secondary_preferred }
            )

            unless r['containers'].nil?
              container_names = r['containers'].split(',')

              scope = scope.where(name: {:$in => container_names})
            end

            unless r['nodes'].nil?
              nodes = r['nodes'].split(',').map do |node_name|
                @grid.host_nodes.find_by(name: node_name).try(:id)
              end.delete_if{|n| n.nil?}

              scope = scope.where(host_node_id: {:$in => nodes})
            end
            unless r['services'].nil?
              services = r['services'].split(',').map do |service|
                if service.include?('/')
                  stack_name, service_name = service.split('/', 2)
                  stack_id = @grid.stacks.where(name: stack_name).first.try(:id)
                  if stack_id && service_name
                    @grid.grid_services.where(stack_id: stack_id, name: service_name).first.try(:id)
                  end
                else
                  @grid.grid_services.find_by(name: service).try(:id)
                end
              end.compact

              scope = scope.where(grid_service_id: {:$in => services})
            end

            render_container_logs(r, scope)
          end

          r.on 'audit_log' do
            limit = (1..3000).cover?(request.params['limit'].to_i) ? request.params['limit'].to_i : 500
            @logs = @grid.audit_logs.with(
              read: { mode: :secondary_preferred }
            ).order(created_at: :desc).limit(limit).to_a.reverse
            render('audit_logs/index')
          end
        end

        r.put do
          # PUT /v1/grids/:name
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

        r.delete do
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
