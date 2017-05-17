
describe '/v1/grids', celluloid: true do
  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid = Grid.create!(name: 'terminal-a')
    grid.users << user

    user
  end

  let(:emily) do
    user = User.create!(email: 'emily@domain.com', external_id: '123457')
    grid = Grid.create!(name: 'terminal-b')
    grid.users << user

    user
  end

  let(:thomas) do
    user = User.create!(email: 'thomas@domain.com', external_id: '123458')
    grid = Grid.create!(name: 'terminal-c')
    grid.users << user

    user
  end

  let(:db_service) do
    grid  = david.grids.first
    GridService.create!(name: 'db', grid: grid, image_name: 'mysql:5.6')
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  describe 'POST' do
    before(:each) do
      allow(GridAuthorizer).to receive(:creatable_by?).with(david).and_return(true)
    end

    it 'creates a new grid' do
      expect {
        post '/v1/grids', {}.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ david.reload.grids.count }.by(1)
    end

    it 'a new grid has a generated token unless supplied' do
      expect {
        post '/v1/grids', {name: 'foo'}.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ david.reload.grids.count }.by(1)
      expect(Grid.where(name: 'foo').first.token).to match(/\A[A-Za-z0-9+\/=]*\Z/)
    end

    it 'creates a new grid with supplied token' do
      expect {
        post '/v1/grids', {name: 'foo', token: 'abcd1234'}.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ david.reload.grids.count }.by(1)
      expect(Grid.where(name: 'foo').first.token).to eq 'abcd1234'
    end

    it 'requires authorization' do
      request_headers.delete('HTTP_AUTHORIZATION')
      post '/v1/grids', {}.to_json, request_headers
      expect(response.status).to eq(403)
    end

    it 'requires valid name' do
      post '/v1/grids', {name: '1'}.to_json, request_headers
      expect(response.status).to eq(422)
      expect(json_response['error'])
    end

    it 'creates audit log entry' do
      expect {
        post '/v1/grids', {}.to_json, request_headers
      }.to change{ AuditLog.count }.by(1)
      audit_log = AuditLog.last
      grid = david.reload.grids.last
      expect(audit_log.event_name).to eq('create')
      expect(audit_log.resource_id).to eq(grid.id.to_s)
      expect(audit_log.grid).to eq(grid)
    end

    describe '/:id/services' do
      it 'creates a new service' do
        grid = david.grids.first
        payload = {
            image: 'foo/bar',
            stateful: false,
            name: 'foo-service'
        }
        expect {
          post "/v1/grids/#{grid.to_path}/services", payload.to_json, request_headers
          expect(response.status).to eq(201)
        }.to change{ grid.grid_services.count }.by(1)
      end

      it 'creates grid_service_links' do
        grid = david.grids.first
        payload = {
            image: 'wordpress',
            stateful: false,
            name: 'wordpress',
            links: [{'name' => "null/#{db_service.name}", 'alias' => 'mysql'}]
        }

        post "/v1/grids/#{grid.to_path}/services", payload.to_json, request_headers

        expect(json_response['links'].size).to eq(1)
        expect(json_response['links'].first['id']).to eq(db_service.to_path)
        expect(json_response['links'].first['alias']).to eq('mysql')
      end
    end

  end

  describe 'GET /' do
    context 'when user is master_admin' do
      it 'returns all grids' do
        david # create
        david.roles << Role.create(name: 'master_admin', description: 'Master admin')
        emily # create

        get "/v1/grids", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['grids'].size).to eq(2)
      end
    end

    it 'returns users grids' do
      david # create
      emily # create
      get "/v1/grids", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['grids'].size).to eq(1)
    end
  end

  describe 'GET /:name' do
    it 'returns grid' do
      grid = david.grids.first
      get "/v1/grids/#{grid.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['id']).to eq(grid.to_path)
      expect(json_response['trusted_subnets']).to eq([])
    end

    describe '/services' do
      it 'returns grid services' do
        grid = david.grids.first
        service = grid.grid_services.create!(name: "foo", image_name: 'foo/bar')
        2.times do |i|
          service.containers.create!(
            name: "#{service.name}-#{i}", grid: grid,
            state: {
              running: true
            }
          )
        end
        service = grid.grid_services.create!(name: "bar", image_name: 'foo/bar')
        3.times do |i|
          service.containers.create!(
            name: "#{service.name}-#{i}", grid: grid,
            state: {
              running: false
            }
          )
        end

        get "/v1/grids/#{grid.to_path}/services", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['services'].size).to eq(2)
        instance = json_response['services'][0]
        expect(instance['instance_counts']['total']).to eq(3)
        expect(instance['instance_counts']['running']).to eq(0)
        instance = json_response['services'][1]
        expect(instance['instance_counts']['total']).to eq(2)
        expect(instance['instance_counts']['running']).to eq(2)
      end

      it 'it returns services for stack' do
        grid = david.grids.first
        stack = grid.stacks.create(name: 'redis')
        redis = stack.grid_services.create(name: 'redis', image_name: 'redis:latest', grid: grid)
        grid.grid_services.create!(name: 'foo', image_name: 'foo/bar')
        get "/v1/grids/#{grid.to_path}/services?stack=redis", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['services'].size).to eq(1)
        expect(json_response['services'][0]['name']).to eq(redis.name)
      end

      it 'it returns services for stack' do
        grid = david.grids.first
        grid.grid_services.create!(name: 'foo', image_name: 'foo/bar')
        get "/v1/grids/#{grid.to_path}/services?stack=redis", nil, request_headers
        expect(response.status).to eq(404)
      end
    end

    describe '/nodes' do
      it 'returns grid nodes' do
        grid = david.grids.first

        grid.host_nodes.create!(node_id: SecureRandom.uuid)
        get "/v1/grids/#{grid.to_path}/nodes", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['nodes'].size).to eq(1)
      end
    end

    describe '/users' do
      it 'returns grid users' do
        grid = david.grids.first
        get "/v1/grids/#{grid.to_path}/users", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['users'].size).to eq(1)
      end
    end

    describe '/container_logs' do
      before do
        @grid = david.grids.first

        node = @grid.host_nodes.create!(name: 'node-1', node_id: SecureRandom.uuid)

        foo_service = @grid.grid_services.create!(name: 'foo', image_name: 'foo/bar')
        bar_service = @grid.grid_services.create!(name: 'bar', image_name: 'bar/foo')

        foo_container1 = foo_service.containers.create!(name: 'foo-1', host_node: node, container_id: 'bbb')
        foo_container1.container_logs.create!(name: "foo-1", data: 'foo-1 1', type: 'stdout', grid: @grid, host_node: node, grid_service: foo_service)

        bar_container1 = bar_service.containers.create!(name: 'bar-1', host_node: node, container_id: 'ccc')
        bar_container1.container_logs.create!(name: "bar-1", data: 'bar-1 1', type: 'stdout', grid: @grid, host_node: node, grid_service: bar_service)
      end

      it 'returns grid container logs' do
        get "/v1/grids/#{@grid.to_path}/container_logs", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(2)
      end

      it 'returns empty logs for an invalid service' do
        get "/v1/grids/#{@grid.to_path}/container_logs?services=quux", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(0)
      end

      it 'returns grid container logs for a service' do
        get "/v1/grids/#{@grid.to_path}/container_logs?services=foo", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(1)
        expect(json_response['logs'].first['data']).to eq('foo-1 1')
      end

      it 'returns grid container logs for multiple services' do
        get "/v1/grids/#{@grid.to_path}/container_logs?services=foo,bar", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(2)
        expect(json_response['logs'][0]['data']).to eq('foo-1 1')
        expect(json_response['logs'][1]['data']).to eq('bar-1 1')
      end

      it 'returns grid container logs for a container' do
        get "/v1/grids/#{@grid.to_path}/container_logs?containers=foo-1", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(1)
        expect(json_response['logs'].first['data']).to eq('foo-1 1')
      end

      it 'returns grid container logs for a node' do
        get "/v1/grids/#{@grid.to_path}/container_logs?nodes=node-1", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(2)
      end

      it 'returns empty logs for an invalid node' do
        get "/v1/grids/#{@grid.to_path}/container_logs?nodes=node-2", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(0)
      end
    end

    describe '/event_logs' do
      let(:grid) { david.grids.first }

      it 'returns empty logs array by default' do
        get "/v1/grids/#{grid.to_path}/event_logs", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(0)
      end

      it 'returns grid events' do
        2.times do |i|
          grid.event_logs.create(msg: "hello #{i}", severity: EventLog::INFO)
        end

        get "/v1/grids/#{grid.to_path}/event_logs", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(2)
      end
    end
  end

  describe 'GET /metrics' do
    let :grid do
       david.grids.first
    end

    let :node do
      grid.host_nodes.create!(name: 'abc', node_id: 'a:b:c')
    end

    before do
      node.host_node_stats.create!({
        grid_id: grid.id,
        memory: {
          total: 1000,
          used: 100
      	},
      	filesystem: [{
          total: 1000,
          used: 10
        }],
      	cpu: {
          num_cores: 2,
          system: 5.5,
          user: 10.0
      	},
        network: {
          internal: {
            interfaces: ["weave", "vethwe123"],
            rx_bytes: 400,
            rx_bytes_per_second: 400.5,
            tx_bytes: 200,
            tx_bytes_per_second: 200.5,
          },
          external: {
            interfaces: ["docker0"],
            rx_bytes: 500,
            rx_bytes_per_second: 500.5,
            tx_bytes: 510,
            tx_bytes_per_second: 510.5
          }
        }
      })
    end

    it 'returns recent stats' do
      get "/v1/grids/#{grid.to_path}/metrics", nil, request_headers

      expect(response.status).to eq(200)
      expect(json_response['stats'].size).to eq 1
      expect(json_response['stats'][0]['cpu']).to eq({ 'used' => 15.5, 'cores' => 2 })
      expect(json_response['stats'][0]['filesystem']).to eq({ 'used' => 10.0, 'total' => 1000.0 })
      expect(json_response['stats'][0]['memory']).to eq({
        'used' => 100.0,
        'total' => 1000.0,
        'active' => 0,
        'inactive' => 0,
        'cached' => 0,
        'buffers' => 0,
        'free' => 0,
      })
      expect(json_response['stats'][0]['network']['internal']).to eq({
        'interfaces' => ["weave", "vethwe123"],
        'rx_bytes' => 400.0,
        'rx_bytes_per_second' => 400.5,
        'tx_bytes' => 200.0,
        'tx_bytes_per_second' => 200.5 })
        expect(json_response['stats'][0]['network']['external']).to eq({
          'interfaces' => ["docker0"],
          'rx_bytes' => 500.0,
          'rx_bytes_per_second' => 500.5,
          'tx_bytes' => 510.0,
          'tx_bytes_per_second' => 510.5 })
    end

    it 'applies date filters' do
      from = Time.parse("2017-01-01 12:00:00 +00:00").utc
      to = Time.parse("2017-01-01 12:15:00 +00:00").utc
      get "/v1/grids/#{grid.to_path}/metrics?from=#{from}&to=#{to}", nil, request_headers

      expect(response.status).to eq(200)
      expect(json_response['stats'].size).to eq 0
      expect(Time.parse(json_response['from'])).to eq from
      expect(Time.parse(json_response['to'])).to eq to
    end
  end

  describe 'POST /:name/users' do
    it 'validates that user belongs to grid' do
      grid = emily.grids.first
      post "/v1/grids/#{grid.to_path}/users", {email: david.email }.to_json, request_headers
      expect(response.status).to eq(403)
    end

    it 'requires existing email' do
      grid = david.grids.first
      post "/v1/grids/#{grid.to_path}/users", {email: 'invalid@domain.com'}.to_json, request_headers
      expect(response.status).to eq(404)
    end
    it 'assigns user to grid' do
      grid = david.grids.first
      expect(UserAuthorizer).to receive(:assignable_by?).with(david, {to: grid}).and_return(true)
      post "/v1/grids/#{grid.to_path}/users", {email: emily.email}.to_json, request_headers
      expect(grid.reload.users.size).to eq(2)
      expect(emily.reload.grids.include?(grid)).to be_truthy
    end

    it 'creates audit log entry' do
      grid = david.grids.first
      allow(UserAuthorizer).to receive(:assignable_by?).with(david, {to: grid}).and_return(true)
      expect {
        post "/v1/grids/#{grid.to_path}/users", {email: emily.email}.to_json, request_headers
      }.to change{ AuditLog.count }.by(1)
      audit_log = AuditLog.last
      expect(audit_log.event_name).to eq('assign user')
      expect(audit_log.resource_id).to eq(emily.id.to_s)
      expect(audit_log.grid).to eq(grid)
    end

    it 'returns array of grid users' do
      grid = david.grids.first
      allow(UserAuthorizer).to receive(:assignable_by?).with(david, {to: grid}).and_return(true)
      post "/v1/grids/#{grid.to_path}/users", {email: emily.email}.to_json, request_headers
      expect(response.status).to eq(201)
      expect(json_response['users'].size).to eq(2)
    end

  end

  describe 'DELETE /:name/users/:email' do
    it 'validates that user belongs to grid' do
      grid = emily.grids.first
      delete "/v1/grids/#{grid.to_path}/users/#{emily.email}", nil, request_headers
      expect(response.status).to eq(403)
    end

    it 'validates that unassigned user belongs to grid' do
      grid = david.grids.first
      grid.users << thomas
      delete "/v1/grids/#{grid.to_path}/users/#{emily.email}", nil, request_headers
      expect(response.status).to eq(422)
    end

    it 'validates that user cannot remove last user from grid' do
      grid = david.grids.first

      delete "/v1/grids/#{grid.to_path}/users/#{david.email}", nil, request_headers
      expect(response.status).to eq(422)
    end

    it 'requires existing email' do
      grid = david.grids.first
      delete "/v1/grids/#{grid.to_path}/users/invalid@domain.com", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'unassigns user from grid' do
      grid = david.grids.first
      grid.users << emily
      delete "/v1/grids/#{grid.to_path}/users/#{emily.email}", nil, request_headers
      expect(grid.reload.users.size).to eq(1)
      expect(emily.reload.grids.include?(grid)).to be_falsey
    end

    it 'creates audit log entry' do
      grid = david.grids.first
      grid.users << emily
      expect {
        delete "/v1/grids/#{grid.to_path}/users/#{emily.email}", nil, request_headers
      }.to change{ AuditLog.count }.by(1)
      audit_log = AuditLog.last
      expect(audit_log.event_name).to eq('unassign user')
      expect(audit_log.resource_id).to eq(emily.id.to_s)
      expect(audit_log.grid).to eq(grid)
    end

    it 'returns array of grid users' do
      grid = david.grids.first
      grid.users << emily
      delete "/v1/grids/#{grid.to_path}/users/#{emily.email}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['users'].size).to eq(1)
    end

  end


  describe 'PUT /:name' do
    before(:each) do
      allow_any_instance_of(GridAuthorizer).to receive(:updatable_by?).with(david).and_return(true)
    end

    it 'requires authorization' do
      request_headers.delete('HTTP_AUTHORIZATION')
      grid = david.grids.first
      put "/v1/grids/#{grid.to_path}", {name: 'new name'}.to_json, request_headers
      expect(response.status).to eq(403)
    end

    it 'requires valid grid' do
      put "/v1/grids/foobar", {}.to_json, request_headers
      expect(response.status).to eq(404)
    end

    it 'updates stats.statsd' do
      grid = david.grids.first
      server = '192.168.89.12'
      port = 8125
      data = {
        stats: {
          statsd: {
            server: server,
            port: port
          }
        }
      }
      put "/v1/grids/#{grid.to_path}", data.to_json, request_headers
      expect(response.status).to eq(200)
      statsd = grid.reload.stats['statsd']
      expect(statsd['server']).to eq(server)
      expect(statsd['port']).to eq(port)
    end

    it 'updates logs' do
      grid = david.grids.first
      data = {
        logs: {
          forwarder: 'fluentd',
          opts: {
            'fluentd-address' => '192.168.89.12:22445'
          }
        }
      }
      put "/v1/grids/#{grid.to_path}", data.to_json, request_headers
      expect(response.status).to eq(200)
      logs = grid.reload.grid_logs_opts
      expect(logs.forwarder).to eq('fluentd')
      expect(logs.opts['fluentd-address']).to eq('192.168.89.12:22445')
      expect(json_response['logs']['forwarder']).to eq('fluentd')
      expect(json_response['logs']['opts']['fluentd-address']).to eq('192.168.89.12:22445')
    end

    it 'disables logs' do
      grid = david.grids.first
      data = {
        logs: {
          forwarder: 'none'
        }
      }
      put "/v1/grids/#{grid.to_path}", data.to_json, request_headers
      expect(response.status).to eq(200)
      expect(grid.reload.grid_logs_opts).to be_nil
    end

    it 'updates trusted_subnets' do
      grid = david.grids.first
      data = {
        trusted_subnets: ['192.168.10.0/24']
      }
      put "/v1/grids/#{grid.to_path}", data.to_json, request_headers
      expect(response.status).to eq(200)
      expect(json_response['trusted_subnets']).to eq(data[:trusted_subnets])

      put "/v1/grids/#{grid.to_path}", {}, request_headers
      expect(response.status).to eq(200)
      expect(json_response['trusted_subnets']).to eq(data[:trusted_subnets])
    end

    it 'returns grid' do
      grid = david.grids.first
      put "/v1/grids/#{grid.to_path}", {name: 'new-name'}.to_json, request_headers

      expect(response.status).to eq(200)
      expect(json_response['id']).to eq(grid.reload.to_path)
    end

    it 'creates audit log entry' do
      grid = david.grids.first
      expect {
        put "/v1/grids/#{grid.to_path}", {name: 'new-name'}.to_json, request_headers
      }.to change{ AuditLog.count }.by(1)
      audit_log = AuditLog.last
      expect(audit_log.event_name).to eq('update')
      expect(audit_log.resource_id).to eq(grid.id.to_s)
      expect(audit_log.grid).to eq(grid)
    end
  end

  describe 'DELETE /:name' do
    before(:each) do
      allow_any_instance_of(GridAuthorizer).to receive(:deletable_by?).with(david).and_return(true)
    end

    it 'requires authorization' do
      request_headers.delete('HTTP_AUTHORIZATION')
      grid = david.grids.first
      delete "/v1/grids/#{grid.to_path}", nil, request_headers
      expect(response.status).to eq(403)
    end

    it 'requires valid grid' do
      delete "/v1/grids/foobar", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'destroys given grid' do
      grid = david.grids.first
      expect {
        delete "/v1/grids/#{grid.to_path}", nil, request_headers
      }.to change{Grid.count}.by(-1)
      expect(response.status).to eq(200)

      expect(Grid.where(id: grid.id).exists?).to be_falsey
    end

    it 'creates audit log entry' do
      grid = david.grids.first
      expect {
        delete "/v1/grids/#{grid.to_path}", nil, request_headers
      }.to change{ AuditLog.count }.by(1)
      audit_log = AuditLog.last
      expect(audit_log.event_name).to eq('delete')
      expect(audit_log.resource_id).to eq(grid.id.to_s)
    end

    context 'when grid has services' do
      it 'returns error' do
        grid = david.grids.first
        db_service
        expect {
          delete "/v1/grids/#{grid.to_path}", nil, request_headers
        }.to change{ Grid.count }.by(0)
        expect(response.status).to eq(422)
      end
    end
  end
end
