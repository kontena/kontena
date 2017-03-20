module V1
  class ContainersApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include LogsHelpers
    include Auditor

    plugin :streaming

    route do |r|

      validate_access_token
      require_current_user

      # @param [String] grid_name
      def load_grid(grid_name)
        grid = Grid.find_by(name: grid_name)
        halt_request(404, {error: 'Grid not found'}) if !grid

        unless current_user.grid_ids.include?(grid.id)
          halt_request(403, {error: 'Access denied'})
        end

        grid
      end

      # @param [Grid] grid
      # @param [String] node_name
      # @param [String] container_name
      def load_grid_container(grid, node_name, container_name)
        node = grid.host_nodes.find_by(name: node_name)
        halt_request(404, {error: 'Node not found'}) if !node
        container = node.containers.find_by(name: container_name)
        halt_request(404, {error: 'Container not found'}) if !container

        container
      end

      r.on ':grid_name' do |grid_name|
        grid = Grid.find_by(name: grid_name)

        r.get do
          # /v1/containers/:grid_name/
          r.is do
            scope = grid.containers.unscoped
            scope = scope.where(:'state.running' => true) unless r['all']
            @containers = scope.order_by(created_at: 1).includes(:host_node, :grid_service, :grid)
            render('containers/index')
          end

          # /v1/containers/:grid_name/stats
          r.on 'stats' do
            @from = r.params["at"] ? Time.parse(r.params["at"]) : (Time.now - 2).utc.change(min: 0)
            @to = @from + 1.minute
            @network_iface = r.params["iface"] ? r.params["iface"] : "eth0"
            @sort = (r.params["by"] ? r.params["by"] : "cpu").to_sym
            @limit = r.params["limit"] ? r.params["limit"].to_i : 10

            r.is do
              @containers = ContainerStat.get_containers_with_stats(grid.id, nil, nil, @from, @to, @network_iface, @sort, @limit)
              render('containers/stats')
            end

            # /v1/containers/:grid_name/stats/nodes/:node_name
            r.on 'nodes/:node_name' do |node_name|
              node = grid.host_nodes.find_by(name: node_name)
              halt_request(404, {error: 'Node Not found'}) if !node

              @containers = ContainerStat.get_containers_with_stats(grid.id, node.id, nil, @from, @to, @network_iface, @sort, @limit)
              render('containers/stats')
            end

            # /v1/containers/:grid_name/stats/services/:service_name
            r.on 'services/:service_name' do |service_name|
              service = grid.grid_services.find_by(name: service_name)
              halt_request(404, {error: 'Service Not found'}) if !service

              @containers = ContainerStat.get_containers_with_stats(grid.id, nil, service.id, @from, @to, @network_iface, @sort, @limit)
              render('containers/stats')
            end
          end

          # /v1/containers/:grid_name/:node_name/:name
          r.on ':node_name/:name' do |node_name, name|
            container = load_grid_container(grid, node_name, name)

            r.get do
              r.is do
                @container = container
                render('containers/show')
              end

              # /v1/containers/:grid_name/:node_name/:name/top
              r.on 'top' do
                client = RpcClient.new(container.host_node.node_id)
                client.request('/containers/top', container.container_id, {})
              end

              # /v1/containers/:grid_name/:node_name/:name/logs
              r.on 'logs' do
                logs = container.container_logs

                render_container_logs(r, logs)
              end

              # /v1/containers/:grid_name/:node_name/:name/inspect
              r.on 'inspect' do
                audit_event(r, container.grid, container, 'inspect')
                Docker::ContainerInspector.new(container).inspect_container
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
        end
      end
    end
  end
end
