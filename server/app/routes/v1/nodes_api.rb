module V1
  class NodesApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers
    include Auditor

    route do |r|

      # @param [String] grid_name
      # @param [String] node_id
      # @return [HostNode]
      def load_grid_node(grid_name, node_id)
        grid = load_grid(grid_name)

        if node_id.include?(':')
          node = grid.host_nodes.find_by(node_id: node_id)
        else
          node = grid.host_nodes.find_by(name: node_id)
        end
        halt_request(404, {error: 'Not found'}) if !node

        node
      end

      r.on ':grid_name/:node_id' do |grid_name, node_id|
        validate_access_token
        require_current_user

        @node = load_grid_node(grid_name, node_id)

        r.get do
          r.is do
            render('host_nodes/show')
          end

          # GET /v1/nodes/:grid/:node/health
          r.on 'health' do
            rpc_client = @node.rpc_client(10)

            begin
              @etcd_health = rpc_client.request("/etcd/health")
            rescue RpcClient::TimeoutError => error
              # overlap with any agent-side errors
              @etcd_health = {error: error.message}
            end

            render('host_nodes/health')
          end

          # GET /v1/nodes/:grid/:node/stats
          r.on 'stats' do
            to = (r.params["to"] ? Time.parse(r.params["to"]) : Time.now).utc
            from = (r.params["from"] ? Time.parse(r.params["from"]) : (to - 1.hour)).utc

            @node_stats = Metrics::HostNodeMetrics.fetch(@node.id, from, to)
            render('host_nodes/stats')
          end
        end

        r.put do
          r.is do
            data = parse_json_body
            params = { host_node: @node }
            params[:labels] = data['labels'] if data['labels']
            outcome = HostNodes::Update.run(params)
            if outcome.success?
              @node = outcome.result
              render('host_nodes/show')
            else
              halt_request(422, {error: outcome.errors.message})
            end
          end
        end

        r.delete do
          r.is do
            audit_event(r, @grid, @node, 'remove node')
            outcome = HostNodes::Remove.run(host_node: @node)
            if outcome.success?
              {}
            else
              halt_request(422, {error: outcome.errors.message})
            end
          end
        end
      end

      # /v1/nodes/:id
      # @deprecated
      r.on ':id' do |id|
        token = r.env['HTTP_KONTENA_GRID_TOKEN']
        grid = Grid.find_by(token: token.to_s)
        halt_request(404, {error: 'Not found'}) unless grid

        @node = grid.host_nodes.find_by(node_id: id)
        halt_request(404, {error: 'Node not found'}) if !@node

        r.get do
          r.is do
            render('host_nodes/show')
          end
        end

        r.put do
          r.is do
            data = parse_json_body
            params = { host_node: @node }
            params[:labels] = data['labels'] if data['labels']
            outcome = HostNodes::Update.run(params)
            if outcome.success?
              @node = outcome.result
              render('host_nodes/show')
            else
              halt_request(422, {error: outcome.errors.message})
            end
          end
        end
      end
    end
  end
end
