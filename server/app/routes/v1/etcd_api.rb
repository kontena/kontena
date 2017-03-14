module V1
  class EtcdApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers

    route do |r|

      validate_access_token
      require_current_user


      # /v1/etcd/:grid_name/:path
      r.on /([^\/]+)\/(.+)/ do |grid_name, path|
        grid = load_grid(grid_name)
        node = grid.host_nodes.connected.first
        halt_request(404, {error: 'Not connected to any nodes'}) if !node

        client = node.rpc_client(2)

        r.get do
          r.is do
            opts = {}
            opts[:recursive] = true if r['recursive']
            client.request("/etcd/get", path, opts)
          end
        end

        r.post do
          r.is do
            data = parse_json_body
            params = {}
            if data['value']
              params[:value] = data['value']
            else
              params[:dir] = true
            end
            client.request("/etcd/set", path, params)
          end
        end

        r.delete do
          r.is do
            data = parse_json_body
            params = {}
            params[:recursive] = data['recursive'] || false
            client.request("/etcd/delete", path, params)
          end
        end
      end
    end
  end
end
