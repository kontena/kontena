module V1
  class ContainersApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include LogsHelpers

    plugin :streaming

    route do |r|

      validate_access_token
      require_current_user

      # @param [String] grid_name
      # @param [String] stack_name
      # @param [String] service_name
      # @param [String] container_name
      def load_grid_container(grid_name, stack_name, service_name, container_name)
        grid = Grid.find_by(name: grid_name)
        halt_request(404, {error: 'Not found'}) if !grid
        stack = grid.stacks.find_by(name: stack_name)
        halt_request(404, {error: 'Not found'}) if !stack
        service = stack.grid_services.find_by(name: service_name)
        halt_request(404, {error: 'Not found'}) if !service
        container = grid.containers.find_by(name: container_name)
        halt_request(404, {error: 'Not found'}) if !container

        unless current_user.grid_ids.include?(service.grid_id)
          halt_request(403, {error: 'Access denied'})
        end

        container
      end

      # /v1/containers/:grid_name/:service_name/:name
      r.on ':grid_name/:stack_name/:service_name/:name' do |grid_name, stack_name, service_name, name|
        container = load_grid_container(grid_name, stack_name, service_name, name)

        # GET /v1/containers/:grid_name/stack_name/:service_name/:name
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
            logs = container.container_logs

            render_container_logs(r, logs)
          end

          r.on 'inspect' do
            Docker::ContainerInspector.new(container).inspect_container
          end
        end

        # POST /v1/containers/:grid_name/:service_name/:name
        r.post do
          r.on 'exec' do
            json = parse_json_body
            Docker::ContainerExecutor.new(container).exec_in_container(json['cmd'])
          end
        end
      end
    end
  end
end
