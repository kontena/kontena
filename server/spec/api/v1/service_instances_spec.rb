describe '/v1/services/:id/event_logs' do

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
    it 'returns service instances' do
      redis_service.grid_service_instances.create!(
        instance_number: 2,
        deploy_rev: Time.now.utc.to_s
      )
      get "/v1/services/#{redis_service.to_path}/instances", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['instances'].size).to eq(1)
    end
  end

  describe 'GET /:id' do
    it 'returns service instance' do
      instance = redis_service.grid_service_instances.create!(
        instance_number: 2,
        deploy_rev: Time.now.utc.to_s
      )
      get "/v1/services/#{redis_service.to_path}/instances/#{instance.id.to_s}", nil, request_headers
      expect(response.status).to eq(200)
    end

    it 'returns error if instance not found' do
      get "/v1/services/#{redis_service.to_path}/instances/00", nil, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'DELETE /:id' do
    it 'removes service instance' do
      node = HostNode.create(grid: grid, node_id: 'a')
      instance = redis_service.grid_service_instances.create!(
        instance_number: 2,
        deploy_rev: Time.now.utc.to_s,
        host_node: node
      )
      expect {
        delete "/v1/services/#{redis_service.to_path}/instances/#{instance.id.to_s}", nil, request_headers
        expect(response.status).to eq(200)
      }.to change { instance.reload.host_node }.from(node).to(nil)
    end
  end
end
