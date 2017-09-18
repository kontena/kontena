
describe '/v1/services' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let! :grid do
    Grid.create!(name: 'terminal-a')
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

  let! :service_with_vol do
    volume = Volume.create(grid: grid, name: 'volume', driver: 'local', scope: 'instance')
    outcome = GridServices::Create.run(grid: grid, stateful: false, name: 'redis-2', image: 'redis:latest', volumes: ['volume:/data'])
    outcome.result
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
        internal: {
          'interfaces' => ['ethwe'], 'rx_bytes' => 1397524, 'rx_bytes_per_second' => 3109, 'tx_bytes' => 1680754, 'tx_bytes_per_second'=>3035
        },
        external: {
          'interfaces' => ['eth0'], 'rx_bytes' => 123, 'rx_bytes_per_second' => 10, 'tx_bytes' => 456, 'tx_bytes_per_second'=>20
        }
      },
      spec: {
        'memory' => { 'limit' => 512000000},
        'cpu' => { 'limit' => 1024, 'mask' => '0-1' }
      }
    }
  end

  EXPECTED_FIELDS = %w(
        id created_at updated_at stack image affinity name stateful user
        instances cmd entrypoint ports env memory memory_swap shm_size cpus cpu_shares
        volumes volumes_from cap_add cap_drop state grid links log_driver log_opts
        strategy deploy_opts pid instance_counts net dns hooks secrets revision
        stack_revision stop_grace_period read_only certificates
      ).sort

  describe 'GET /:id' do
    it 'returns stackless service json' do
      get "/v1/services/terminal-a/null/redis", nil, request_headers
      expect(response.status).to eq(200), response.body
      expect(json_response.keys.sort).to eq(EXPECTED_FIELDS)
      expect(json_response['id']).to eq('terminal-a/null/redis')
      expect(json_response['image']).to eq(redis_service.image_name)
      expect(json_response['dns']).to eq('redis.terminal-a.kontena.local')
    end

    it 'returns stack service json' do
      get "/v1/services/terminal-a/teststack/redis", nil, request_headers
      expect(response.status).to eq(200), response.body
      expect(json_response.keys.sort).to eq(EXPECTED_FIELDS)
      expect(json_response['id']).to eq('terminal-a/teststack/redis')
      expect(json_response['stack']['name']).to eq('teststack')
      expect(json_response['image']).to eq(stack_redis_service.image_name)
      expect(json_response['dns']).to eq('redis.teststack.terminal-a.kontena.local')
    end

    it 'returns stack service json with volumes' do
      get "/v1/services/terminal-a/null/redis-2", nil, request_headers
      expect(response.status).to eq(200), response.body
      expect(json_response.keys.sort).to eq(EXPECTED_FIELDS)
      expect(json_response['volumes']).to eq(['volume:/data'])
    end

    it 'returns error without authorization' do
      request_headers.delete('HTTP_AUTHORIZATION')
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(403)
    end

    it 'returns health status' do
      redis_service.health_check = GridServiceHealthCheck.new(port: 5000, protocol: 'tcp')
      redis_service.save
      redis_service.containers.create!(name: 'redis-1', container_id: 'aaa', health_status: 'healthy')
      redis_service.containers.create!(name: 'redis-2', container_id: 'bbb', health_status: 'unhealthy')
      redis_service.containers.create!(name: 'redis-3', container_id: 'ccc')
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['health_status']['total']).to eq(3)
      expect(json_response['health_status']['healthy']).to eq(1)
      expect(json_response['health_status']['unhealthy']).to eq(1)
    end

    it 'returns no health check or status if protocol nil' do
      redis_service.health_check = GridServiceHealthCheck.new(port: 5000)
      redis_service.save
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['health_status']).to be_nil
      expect(json_response['health_check']).to be_nil
    end

    it 'returns stop_grace_period' do
      redis_service.stop_grace_period = 37
      redis_service.save
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['stop_grace_period']).to eq(37)
    end

    it 'returns certificates' do
      redis_service.certificates << GridServiceCertificate.new(subject: 'kontena.io', name: 'SSL_CERTS', type: 'env')
      redis_service.save
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['certificates'].size).to eq(1)
      expect(json_response['certificates'][0]).to eq({'subject' => 'kontena.io', 'name' => 'SSL_CERTS', 'type' => 'env'})
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

  describe 'GET /:id/stats' do
    context 'when container has stats data' do
      it 'returns service stats' do
        container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa', state: { running: true })
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
        expect(json_response['stats'].first['network']['internal']['interfaces']).to eq(['ethwe'])
        expect(json_response['stats'].first['network']['internal']['rx_bytes']).to eq(1397524)
        expect(json_response['stats'].first['network']['internal']['rx_bytes_per_second']).to eq(3109)
        expect(json_response['stats'].first['network']['internal']['tx_bytes']).to eq(1680754)
        expect(json_response['stats'].first['network']['internal']['tx_bytes_per_second']).to eq(3035)
        expect(json_response['stats'].first['network']['external']['interfaces']).to eq(['eth0'])
        expect(json_response['stats'].first['network']['external']['rx_bytes']).to eq(123)
        expect(json_response['stats'].first['network']['external']['rx_bytes_per_second']).to eq(10)
        expect(json_response['stats'].first['network']['external']['tx_bytes']).to eq(456)
        expect(json_response['stats'].first['network']['external']['tx_bytes_per_second']).to eq(20)
      end

      it 'can sort and limit service stats' do
        stats1 = container_stat_data.deep_dup
        stats2 = container_stat_data.deep_dup
        stats3 = container_stat_data.deep_dup

        stats1[:network][:internal]['tx_bytes'] = 20
        stats2[:network][:internal]['tx_bytes'] = 50
        stats3[:network][:internal]['tx_bytes'] = 40

        container1 = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa', state: { running: true })
        container1.container_stats.create!(stats1)

        container2 = redis_service.containers.create!(name: 'redis-2', container_id: 'bbb', state: { running: true })
        container2.container_stats.create!(stats2)

        container3 = redis_service.containers.create!(name: 'redis-3', container_id: 'ccc', state: { running: true })
        container3.container_stats.create!(stats3)

        get "/v1/services/#{redis_service.to_path}/stats?sort=tx_bytes&limit=1", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['stats'].size).to eq(1)
        expect(json_response['stats'].first['container_id']).to eq(container2.name.to_s)
      end
    end
    context 'when container has not stats data' do
      it 'returns empty result' do
        redis_service.containers.create!(name: 'redis-1', container_id: 'aaa', state: { running: true })
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
        container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa', state: { running: true })
        container_stat_data['grid_service_id'] = redis_service.id
        container.container_stats.create!(container_stat_data)
        get "/v1/services/#{redis_service.to_path}/metrics", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['stats'].size).to eq(1)

      end
    end
    context 'when container has not stats data' do
      it 'returns empty result' do
        redis_service.containers.create!(name: 'redis-1', container_id: 'aaa', state: { running: true })
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
