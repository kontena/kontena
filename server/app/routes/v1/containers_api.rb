module V1
  class ContainersApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include LogsHelpers
    include Auditor

    plugin :streaming
    plugin :websockets, :adapter => :puma, :ping => 30

    route do |r|

      validate_access_token
      require_current_user

      # @param [String] grid_name
      # @param [String] node_name
      # @param [String] container_name
      def load_grid_container(grid_name, node_name, container_name)
        grid = load_grid(grid_name)
        node = grid.host_nodes.find_by(name: node_name)
        halt_request(404, {error: 'Not found'}) if !node
        container = node.containers.find_by(name: container_name)
        halt_request(404, {error: 'Not found'}) if !container

        container
      end

      # /v1/containers/:grid_name/:node_name/:name
      r.on ':grid_name/:node_name/:name' do |grid_name, node_name, name|
        container = load_grid_container(grid_name, node_name, name)

        # GET /v1/containers/:grid_name/:node/:name
        r.get do
          r.is do
            @container = container
            render('containers/show')
          end

          r.on 'top' do
            client = RpcClient.new(container.host_node.node_id)
            client.request('/containers/top', container.container_id, {})
          end

          r.on 'logs' do
            logs = container.container_logs.includes(:host_node, :grid, :grid_service)

            render_container_logs(r, logs)
          end

          r.on 'inspect' do
            audit_event(r, container.grid, container, 'inspect')
            Docker::ContainerInspector.new(container).inspect_container
          end

          r.on 'exec' do
            executor = Docker::StreamingExecutor.new(container,
              interactive: r['interactive'].to_s == 'true',
              shell: r['shell'].to_s == 'true',
              tty: r['tty'].to_s == 'true',
            )
            audit_event(r, container.grid, container, executor.interactive? ? 'exec_interactive' : 'exec')
            executor.setup

            begin
              r.websocket do |ws|
                # this is not allowed to fail
                executor.start(ws)
              end
            ensure
              # only relevant if the request wasn't actually a websocket request
              executor.teardown unless executor.started?
            end
          end
        end

        # POST /v1/containers/:node_name/:name
        r.post do
          r.on 'exec' do
            json = parse_json_body
            audit_event(r, container.grid, container, 'exec')
            Docker::ContainerExecutor.new(container).exec_in_container(json['cmd'])
          end
        end
      end

      # /v1/containers/:grid_name/:node_name/:name
      r.on ':grid_name' do |grid_name|
        grid = load_grid(grid_name)

        r.get do
          r.is do
            scope = grid.containers.unscoped
            scope = scope.where(:'state.running' => true) unless r['all']
            @containers = scope.order_by(created_at: 1).includes(:host_node, :grid_service, :grid)
            render('containers/index')
          end
        end
      end
    end
  end
end
