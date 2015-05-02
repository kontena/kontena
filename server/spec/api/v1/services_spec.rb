require_relative '../../spec_helper'

describe '/v1/services' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token}"
    }
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid = Grid.create!(name: 'Terminal A')
    grid.users << user

    user
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  let(:redis_service) do
    GridService.create!(
      grid: david.grids.first,
      name: 'redis',
      image_name: 'redis:2.8',
      stateful: true
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
      get "/v1/services/#{redis_service.name}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['id']).to eq(redis_service.name.to_s)
      expect(json_response['image']).to eq(redis_service.image_name)
    end

    it 'returns error without authorization' do
      request_headers.delete('HTTP_AUTHORIZATION')
      get "/v1/services/#{redis_service.name}", nil, request_headers
      expect(response.status).to eq(403)
    end
  end

  describe 'GET /:id/containers' do
    it 'returns service containers' do
      container = redis_service.containers.create!(name: 'redis-1')
      get "/v1/services/#{redis_service.name}/containers", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['containers'].size).to eq(1)
      expect(json_response['containers'].first['id']).to eq(container.name.to_s)
    end
  end

  describe 'GET /:id/container_logs' do
    it 'returns service container logs' do
      container = redis_service.containers.create!(name: 'redis-1')
      container.container_logs.create!(data: 'foo', type: 'stdout', grid_service: redis_service)
      get "/v1/services/#{redis_service.name}/container_logs", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['logs'].size).to eq(1)
      expect(json_response['logs'].first['data']).to eq('foo')
    end

    context 'when from parameter is passed' do
      it 'returns service container logs created after passed id' do
        container = redis_service.containers.create!(name: 'redis-1')
        log1 = container.container_logs.create!(data: 'foo', type: 'stdout', grid_service: redis_service)
        log2 = container.container_logs.create!(data: 'foo2', type: 'stdout', grid_service: redis_service)
        get "/v1/services/#{redis_service.name}/container_logs?from=#{log1.id}", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(1)
        expect(json_response['logs'].first['data']).to eq('foo2')
      end

    end
  end

  describe 'GET /:id/stats' do
    context 'when container has stats data' do
      it 'returns service stats' do
        container = redis_service.containers.create!(name: 'redis-1')
        container.container_stats.create!(container_stat_data)
        get "/v1/services/#{redis_service.name}/stats", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['stats'].size).to eq(1)
        expect(json_response['stats'].first.keys).to eq(%w(container_id cpu memory network))
        expect(json_response['stats'].first['container_id']).to eq(container.name.to_s)

      end
    end
    context 'when container has not stats data' do
      it 'returns empty result' do
        redis_service.containers.create!(name: 'redis-1')
        get "/v1/services/#{redis_service.name}/stats", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['stats'].size).to eq(1)
        expect(json_response['stats'].first.keys).to eq(%w(container_id cpu memory network))
        expect(json_response['stats'].first['cpu']).to be_nil
      end
    end
  end

  describe 'POST /:id/deploy' do
    it 'deploys service' do
      expect(GridServices::Deploy).to receive(:run)
        .with(current_user: david, grid_service: redis_service)
        .and_return(double.as_null_object)
      post "/v1/services/#{redis_service.name}/deploy", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'POST /:id/stop' do
    it 'stops service' do
      expect(GridServices::Stop).to receive(:run)
        .with(current_user: david, grid_service: redis_service)
        .and_return(double.as_null_object)
      post "/v1/services/#{redis_service.name}/stop", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'POST /:id/start' do
    it 'starts service' do
      expect(GridServices::Start).to receive(:run)
        .with(current_user: david, grid_service: redis_service)
        .and_return(double.as_null_object)
      post "/v1/services/#{redis_service.name}/start", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'POST /:id/restart' do
    it 'restarts service' do
      expect(GridServices::Restart).to receive(:run)
       .with(current_user: david, grid_service: redis_service)
       .and_return(double.as_null_object)
      post "/v1/services/#{redis_service.name}/restart", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'DELETE /:id' do
    it 'removes service' do
      expect(GridServices::Delete).to receive(:run)
        .with(current_user: david, grid_service: redis_service)
        .and_return(double.as_null_object)
      delete "/v1/services/#{redis_service.name}", nil, request_headers
      expect(response.status).to eq(200)
    end
  end


end
