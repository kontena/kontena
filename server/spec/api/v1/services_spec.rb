
describe '/v1/services' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let! :grid do
    grid = Grid.create!(name: 'terminal-a')
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid.users << user

    user
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  let(:app_service) do
    GridService.create!(
      grid: grid,
      name: 'app',
      image_name: 'my/app:latest',
      stateful: false
    )
  end

  let! :redis_service do
    grid.grid_services.create!(
      name: 'redis',
      image_name: 'redis:2.8',
      stateful: true,
      env: ['FOO=BAR']
    )
  end

  let! :stack do
    grid.stacks.create!(
      name: 'teststack',
    )
  end

  let! :stack_redis_service do
    stack.grid_services.create!(
      grid: grid,
      name: 'redis',
      image_name: 'redis:2.8',
      stateful: true,
      env: ['FOO=BAR']
    )
  end

  let(:container_stat_data) do
    {
      memory: { 'usage' => 100000 },
      cpu: { 'usage_pct' => 10 },
      network: {
        interfaces: [{
          'name' => 'eth0', 'rx_bytes' => 1397524, 'rx_packets' => 3109, 'rx_errors' => 0, 'rx_dropped' => 0, 'tx_bytes' => 1680754, 'tx_packets'=>3035, 'tx_errors'=>0, 'tx_dropped'=>0
        }],
        'name' => 'xxx', 'rx_bytes' => 123, 'rx_packets' => 456, 'rx_errors' => 0, 'rx_dropped' => 0, 'tx_bytes' => 789, 'tx_packets'=>111, 'tx_errors'=>0, 'tx_dropped'=>0
      },
      spec: {
          'memory' => { 'limit' => 512000000},
          'cpu' => { 'limit' => 1024, 'mask' => '0-1' }
      }
    }
  end

  describe 'GET /:id' do
    it 'returns stackless service json' do
      get "/v1/services/terminal-a/null/redis", nil, request_headers
      expect(response.status).to eq(200), response.body
      expect(json_response.keys.sort).to eq(%w(
        id created_at updated_at stack image affinity name stateful user
        instances cmd entrypoint ports env memory memory_swap cpu_shares
        volumes volumes_from cap_add cap_drop state grid links log_driver log_opts
        strategy deploy_opts pid instance_counts net dns hooks secrets revision
        stack_revision
      ).sort)
      expect(json_response['id']).to eq('terminal-a/null/redis')
      expect(json_response['image']).to eq(redis_service.image_name)
      expect(json_response['dns']).to eq('redis.terminal-a.kontena.local')
    end

    it 'returns stack service json' do
      get "/v1/services/terminal-a/teststack/redis", nil, request_headers
      expect(response.status).to eq(200), response.body
      expect(json_response.keys.sort).to eq(%w(
        id created_at updated_at stack image affinity name stateful user
        instances cmd entrypoint ports env memory memory_swap cpu_shares
        volumes volumes_from cap_add cap_drop state grid links log_driver log_opts
        strategy deploy_opts pid instance_counts net dns hooks secrets revision
        stack_revision
      ).sort)
      expect(json_response['id']).to eq('terminal-a/teststack/redis')
      expect(json_response['stack']['name']).to eq('teststack')
      expect(json_response['image']).to eq(stack_redis_service.image_name)
      expect(json_response['dns']).to eq('redis.teststack.terminal-a.kontena.local')
    end

    it 'returns error without authorization' do
      request_headers.delete('HTTP_AUTHORIZATION')
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(403)
    end

    it 'returns health status' do
      redis_service.health_check = GridServiceHealthCheck.new(port: 5000, protocol: 'tcp')
      redis_service.save
      container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa', health_status: 'healthy')
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['health_status']['total']).to eq(1)
      expect(json_response['health_status']['healthy']).to eq(1)
    end

    it 'returns no health check or status if protocol nil' do
      redis_service.health_check = GridServiceHealthCheck.new(port: 5000)
      redis_service.save
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['health_status']).to be_nil
      expect(json_response['health_check']).to be_nil
    end
  end

  describe 'PUT /:id' do
    it 'updates service links' do
      redis_service
      data = {
        links: [
          {name: 'null/redis', alias: 'redis'}
        ]
      }
      put "/v1/services/#{app_service.to_path}", data.to_json, request_headers
      expect(response.status).to eq(200)
      expect(json_response['links']).to include({
        'alias' => 'redis', 'id' => redis_service.to_path, 'name' => redis_service.name
      })
    end

    it 'resets links if array is empty' do
      app_service.grid_service_links << GridServiceLink.new(
        linked_grid_service: redis_service,
        alias: 'redis'
      )
      app_service.save!
      data = {
        links: []
      }
      put "/v1/services/#{app_service.to_path}", data.to_json, request_headers
      expect(response.status).to eq(200)
      expect(json_response['links']).to eq([])
    end

    it 'returns error when linked service does not exist' do
      data = {
        links: [
          {name: 'null/foo', alias: 'redis'}
        ]
      }
      put "/v1/services/#{app_service.to_path}", data.to_json, request_headers
      expect(response.status).to eq(422)
    end
  end

  describe 'GET /:id/containers' do
    it 'returns service containers' do
      container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
      get "/v1/services/#{redis_service.to_path}/containers", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['containers'].size).to eq(1)
      expect(json_response['containers'].first['id']).to eq(container.to_path)
    end
  end

  describe 'GET /:id/container_logs' do
    it 'returns service container logs' do
      container = redis_service.containers.create!(name: 'redis-1', container_id: 'bbb')
      container.container_logs.create!(data: 'foo', type: 'stdout', grid_service: redis_service)
      get "/v1/services/#{redis_service.to_path}/container_logs", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['logs'].size).to eq(1)
      expect(json_response['logs'].first['data']).to eq('foo')
    end

    context 'when instance parameter is passed' do
      it 'returns service container logs for related instance' do
        container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
        container2 = redis_service.containers.create!(name: 'redis-2', container_id: 'bbb')
        log1 = container.container_logs.create!(name: 'redis-1', instance_number: 1, data: 'foo', type: 'stdout', grid_service: redis_service)
        log2 = container2.container_logs.create!(name: 'redis-2', instance_number: 2, data: 'foo2', type: 'stdout', grid_service: redis_service)
        get "/v1/services/#{redis_service.to_path}/container_logs?instance=1", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(1)
        expect(json_response['logs'].first['data']).to eq('foo')
      end
    end

    context 'when from parameter is passed' do
      it 'returns service container logs created after passed id' do
        container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
        log1 = container.container_logs.create!(data: 'foo', type: 'stdout', grid_service: redis_service)
        log2 = container.container_logs.create!(data: 'foo2', type: 'stdout', grid_service: redis_service)
        get "/v1/services/#{redis_service.to_path}/container_logs?from=#{log1.id}", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(1)
        expect(json_response['logs'].first['data']).to eq('foo2')
      end
    end

    context 'when since parameter is passed' do
      it 'returns service container logs created after passed timestamp' do
        container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
        log1 = container.container_logs.create!(
          data: 'foo', type: 'stdout', grid_service: redis_service, created_at: 5.minutes.ago
        )
        log2 = container.container_logs.create!(
          data: 'foo2', type: 'stdout', grid_service: redis_service, created_at: 3.minutes.ago
        )
        log3 = container.container_logs.create!(
          data: 'foo3', type: 'stdout', grid_service: redis_service, created_at: 1.minutes.ago
        )
        get "/v1/services/#{redis_service.to_path}/container_logs?since=#{log2.created_at}", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(2)
        expect(json_response['logs'].first['data']).to eq('foo2')
      end
    end

    context 'when limit parameter is passed' do
      before do
        stub_const('LogsHelpers::LOGS_LIMIT_DEFAULT', 10)
        stub_const('LogsHelpers::LOGS_LIMIT_MAX', 20)

        container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
        (1..100).each do |i|
          container.container_logs.create!(data: "log #{i}", type: 'stdout', grid_service: redis_service)
        end
      end

      it 'accepts a smaller value' do
        get "/v1/services/#{redis_service.to_path}/container_logs?limit=2", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(2)
      end

      it 'ignores an invalid value' do
        get "/v1/services/#{redis_service.to_path}/container_logs?limit=foo", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(10)
      end

      it 'ignores an zero value' do
        get "/v1/services/#{redis_service.to_path}/container_logs?limit=0", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(10)
      end

      it 'limits the maximum value' do
        get "/v1/services/#{redis_service.to_path}/container_logs?limit=100", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(20)
      end
    end
  end

  describe 'GET /:id/stats' do
    context 'when container has stats data' do
      it 'returns service stats' do
        container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
        container.container_stats.create!(container_stat_data)
        get "/v1/services/#{redis_service.to_path}/stats", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['stats'].size).to eq(1)
        expect(json_response['stats'].first.keys).to eq(%w(container_id cpu memory network))
        expect(json_response['stats'].first['container_id']).to eq(container.name.to_s)
        expect(json_response['stats'].first['cpu']['usage']).to eq(10)
        expect(json_response['stats'].first['cpu']['limit']).to eq(1024)
        expect(json_response['stats'].first['cpu']['num_cores']).to eq(2)
        expect(json_response['stats'].first['memory']['usage']).to eq(100000)
        expect(json_response['stats'].first['memory']['limit']).to eq(512000000)
        expect(json_response['stats'].first['network']['name']).to eq('eth0')
        expect(json_response['stats'].first['network']['rx_bytes']).to eq(1397524)
        expect(json_response['stats'].first['network']['tx_bytes']).to eq(1680754)

      end
    end
    context 'when container has not stats data' do
      it 'returns empty result' do
        redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
        get "/v1/services/#{redis_service.to_path}/stats", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['stats'].size).to eq(1)
        expect(json_response['stats'].first.keys).to eq(%w(container_id cpu memory network))
        expect(json_response['stats'].first['cpu']).to be_nil
      end
    end
  end

  describe 'GET /:id/metrics' do
    context 'when container has stats data' do
      it 'returns service metrics' do
        container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
        container_stat_data['grid_service_id'] = redis_service.id
        container.container_stats.create!(container_stat_data)
        get "/v1/services/#{redis_service.to_path}/metrics", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['stats'].size).to eq(1)

      end
    end
    context 'when container has not stats data' do
      it 'returns empty result' do
        redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
        get "/v1/services/#{redis_service.to_path}/metrics", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['stats'].size).to eq(0)
      end
    end
  end

  describe 'GET /:id/deploys/:deploy_id' do
    it 'returns deploy object' do
      deployment = redis_service.grid_service_deploys.create
      get "/v1/services/#{redis_service.to_path}/deploys/#{deployment.id}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['id']).to eq(deployment.id.to_s)
    end

    it 'returns 404 if deploy not found' do
      get "/v1/services/#{redis_service.to_path}/deploys/foo", nil, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'POST /:id/deploy' do
    it 'deploys service' do
      expect {
        post "/v1/services/#{redis_service.to_path}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{ redis_service.grid_service_deploys.count }.by(1)
    end

    it 'returns deploy object' do
      post "/v1/services/#{redis_service.to_path}/deploy", nil, request_headers
      expect(response.status).to eq(200)
      expect(GridServiceDeploy.find(json_response['id'])).not_to be_nil
    end

    it 'changes state to deploy_pending' do
      expect {
        post "/v1/services/#{redis_service.to_path}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{ redis_service.reload.deploy_pending? }.from(false).to(true)
    end

    it 'does not change updated_at by default' do
      expect {
        post "/v1/services/#{redis_service.to_path}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.not_to change{ redis_service.reload.updated_at }
    end

    it 'changes updated_at when force=true' do
      expect {
        post "/v1/services/#{redis_service.to_path}/deploy", {force: true}.to_json, request_headers
        expect(response.status).to eq(200)
      }.to change{ redis_service.reload.updated_at }
    end
  end

  describe 'POST /:id/stop' do
    it 'stops service' do
      expect(GridServices::Stop).to receive(:run)
        .with(grid_service: redis_service)
        .and_return(double.as_null_object)
      post "/v1/services/#{redis_service.to_path}/stop", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'POST /:id/start' do
    it 'starts service' do
      expect(GridServices::Start).to receive(:run)
        .with(grid_service: redis_service)
        .and_return(double.as_null_object)
      post "/v1/services/#{redis_service.to_path}/start", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'POST /:id/restart' do
    it 'restarts service' do
      expect(GridServices::Restart).to receive(:run)
       .with(grid_service: redis_service)
       .and_return(double.as_null_object)
      post "/v1/services/#{redis_service.to_path}/restart", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'DELETE /:id' do
    it 'returns error hash on error' do
      outcome = double
      allow(outcome).to receive(:success?).and_return(false)
      errors = double
      allow(errors).to receive(:message).and_return({ service: "Cannot delete service because it's currently being deployed"})
      allow(outcome).to receive(:errors).and_return(errors)
      expect(GridServices::Delete).to receive(:run)
        .with(grid_service: redis_service)
        .and_return(outcome)
      delete "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(422)
      expect(json_response).to eq({ 'error' => { 'service' => "Cannot delete service because it's currently being deployed" }})
    end

    it 'removes service' do
      expect(GridServices::Delete).to receive(:run)
        .with(grid_service: redis_service)
        .and_return(double.as_null_object)
      delete "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'POST /:id/envs' do
    it 'adds env variable' do
      data = {env: 'BAR=BAZ'}
      post "/v1/services/#{redis_service.to_path}/envs", data.to_json, request_headers
      expect(response.status).to eq(200)
      expect(redis_service.reload.env).to include('BAR=BAZ')
    end
  end

  describe 'DELETE /:id/envs' do
    it 'removes env variable' do
      delete "/v1/services/#{redis_service.to_path}/envs/FOO", nil, request_headers
      expect(response.status).to eq(200)
      expect(redis_service.reload.env).to eq([])
    end
  end
end
