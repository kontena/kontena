
describe '/v1/services/:id/container_logs' do

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

  let! :redis_service do
    grid.grid_services.create!(
      name: 'redis',
      image_name: 'redis:2.8',
      stateful: true,
      env: ['FOO=BAR']
    )
  end

  describe 'GET' do
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
        container.container_logs.create!(name: 'redis-1', instance_number: 1, data: 'foo', type: 'stdout', grid_service: redis_service)
        container2.container_logs.create!(name: 'redis-2', instance_number: 2, data: 'foo2', type: 'stdout', grid_service: redis_service)
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
        container.container_logs.create!(data: 'foo2', type: 'stdout', grid_service: redis_service)
        get "/v1/services/#{redis_service.to_path}/container_logs?from=#{log1.id}", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(1)
        expect(json_response['logs'].first['data']).to eq('foo2')
      end
    end

    context 'when since parameter is passed' do
      it 'returns service container logs created after passed timestamp' do
        container = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
        container.container_logs.create!(
          data: 'foo', type: 'stdout', grid_service: redis_service, created_at: 5.minutes.ago
        )
        log2 = container.container_logs.create!(
          data: 'foo2', type: 'stdout', grid_service: redis_service, created_at: 3.minutes.ago
        )
        container.container_logs.create!(
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
end
