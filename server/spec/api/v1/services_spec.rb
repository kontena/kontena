require_relative '../../spec_helper'

describe '/v1/services' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token}"
    }
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid = Grid.create!(name: 'terminal-a')
    grid.users << user

    user
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  let(:app_service) do
    GridService.create!(
      grid: david.grids.first,
      name: 'app',
      image_name: 'my/app:latest',
      stateful: false
    )
  end

  let(:redis_service) do
    GridService.create!(
      grid: david.grids.first,
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
          'rx_bytes' => 1397524, 'rx_packets' => 3109, 'rx_errors' => 0, 'rx_dropped' => 0, 'tx_bytes' => 1680754, 'tx_packets'=>3035, 'tx_errors'=>0, 'tx_dropped'=>0
      },
      spec: {
          'memory' => { 'limit' => 512000000},
          'cpu' => { 'limit' => 1024}
      }
    }
  end

  describe 'GET /:id' do
    it 'returns service json' do
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response.keys.sort).to eq(%w(
        id created_at updated_at image affinity name stateful user
        container_count cmd entrypoint ports env memory memory_swap cpu_shares
        volumes volumes_from cap_add cap_drop state grid_id links log_driver log_opts
        strategy deploy_opts pid instances net hooks secrets revision
      ).sort)
      expect(json_response['id']).to eq(redis_service.to_path)
      expect(json_response['image']).to eq(redis_service.image_name)
    end

    it 'returns error without authorization' do
      request_headers.delete('HTTP_AUTHORIZATION')
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(403)
    end

    it 'returns health status' do
      redis_service.health_check = GridServiceHealthCheck.new(port: 5000)
      redis_service.save
      container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa', health_status: 'healthy')
      get "/v1/services/#{redis_service.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['health_status']['total']).to eq(1)
      expect(json_response['health_status']['healthy']).to eq(1)
    end
  end

  describe 'PUT /:id' do
    it 'updates service links' do
      redis_service
      data = {
        links: [
          {name: 'redis', alias: 'redis'}
        ]
      }
      put "/v1/services/#{app_service.to_path}", data.to_json, request_headers
      expect(response.status).to eq(200)
      expect(json_response['links']).to include({
        'alias' => 'redis', 'grid_service_id' => redis_service.to_path
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
          {name: 'foo', alias: 'redis'}
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

  describe 'POST /:id/deploy' do
    it 'deploys service' do
      expect {
        post "/v1/services/#{redis_service.to_path}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{ redis_service.grid_service_deploys.count }.by(1)
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
        .with(current_user: david, grid_service: redis_service)
        .and_return(double.as_null_object)
      post "/v1/services/#{redis_service.to_path}/stop", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'POST /:id/start' do
    it 'starts service' do
      expect(GridServices::Start).to receive(:run)
        .with(current_user: david, grid_service: redis_service)
        .and_return(double.as_null_object)
      post "/v1/services/#{redis_service.to_path}/start", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'POST /:id/restart' do
    it 'restarts service' do
      expect(GridServices::Restart).to receive(:run)
       .with(current_user: david, grid_service: redis_service)
       .and_return(double.as_null_object)
      post "/v1/services/#{redis_service.to_path}/restart", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'DELETE /:id' do
    it 'removes service' do
      expect(GridServices::Delete).to receive(:run)
        .with(current_user: david, grid_service: redis_service)
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
