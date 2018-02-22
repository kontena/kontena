
describe '/v1/containers' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let(:rpc_client) do
    spy(:client)
  end

  let(:docker_executor) do
    spy(:executor)
  end

  let(:docker_inspector) do
    spy(:inspector)
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
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

  let(:host_node) do
    david.grids.first.create_node!('node-a', node_id: 'abc')
  end

  let(:redis_service) do
    GridService.create!(
        grid: david.grids.first,
        name: 'redis',
        image_name: 'redis:2.8',
        stateful: true
    )
  end

  let(:redis_container) do
    Container.create!(
        grid: redis_service.grid,
        grid_service: redis_service,
        name: 'redis-1',
        image: 'redis:2.8',
        host_node: host_node,
        state: {
          running: true
        }
    )
  end

  let(:log_entry) do
    ContainerLog.create!(container: redis_container, grid_service: redis_service, grid: redis_service.grid, type: 'info', data: 'log entry', name: 'log name')
  end

  describe 'GET /' do
    it 'returns list of containers' do
      get "/v1/containers/#{redis_container.grid.to_path}", {}, request_headers
      expect(response.status).to eq(200)
      expect(json_response['containers'].size).to eq(1)
    end
  end

  describe 'GET /:name' do
    it 'returns service container' do
      get "/v1/containers/#{redis_container.to_path}", {}, request_headers
      expect(response.status).to eq(200)

      expect(json_response['id']).to eq(redis_container.to_path)
    end

    it 'returns service container with health status' do
      redis_container.update_attributes(
        health_status: 'healthy',
        health_status_at: Time.now
      )
      get "/v1/containers/#{redis_container.to_path}", {}, request_headers
      expect(response.status).to eq(200)

      expect(json_response['id']).to eq(redis_container.to_path)
      expect(json_response['health_status']['status']).to eq('healthy')
      expect(json_response['health_status']['updated_at']).not_to be_nil
    end

    describe '/top' do
      it 'makes rpc request to host node' do
        expect(RpcClient).to receive(:new).with(host_node.node_id).and_return(rpc_client)
        expect(rpc_client).to receive(:request).and_return({})
        get "/v1/containers/#{redis_container.to_path}/top", {}, request_headers
        expect(response.status).to eq(200)
      end
    end

    describe '/logs' do
      it 'return container logs' do
        log_entry
        get "/v1/containers/#{redis_container.to_path}/logs", {}, request_headers
        expect(response.status).to eq(200)
        expect(json_response['logs'].size).to eq(1)
        expect(json_response['logs'].first['container_id']).to eq(redis_container.id.to_s)
      end
    end

    describe '/inspect' do
      it 'return container info' do
        expect(Docker::ContainerInspector).to receive(:new).with(redis_container).and_return(docker_inspector)
        expect(docker_inspector).to receive(:inspect_container)
        get "/v1/containers/#{redis_container.to_path}/inspect", {}, request_headers
      end
    end
  end

  describe 'POST /exec' do
    it 'calls Docker::ContainerExecutor#exec_in_container with given command' do
      command = '/bin/bash'
      expect(Docker::ContainerExecutor).to receive(:new).with(redis_container).and_return(docker_executor)
      expect(docker_executor).to receive(:exec_in_container).with(command)
      post "/v1/containers/#{redis_container.to_path}/exec", {cmd: '/bin/bash'}.to_json, request_headers
    end
  end
end
