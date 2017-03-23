
describe '/v1/stacks/:id/container_logs', celluloid: true do

  let(:grid) do
    Grid.create!(name: 'terminal-a')
  end

  let(:stack) { grid.stacks.first }

  let(:node) { HostNode.create(name: 'node', node_id: 'node') }

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid.users << user

    user
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  let(:request_headers) do
    { 'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}" }
  end

  let(:test_app) do
    GridService.create!(
      grid: david.grids.first,
      name: 'app',
      image_name: 'my/app:latest',
      stateful: false,
      stack: stack
    )
  end

  describe 'GET' do
    it 'requires autentication' do
      get "/v1/stacks/#{stack.to_path}/container_logs"
      expect(response.status).to eq(403)
    end

    it 'returns empty array when no log items exist' do
      get "/v1/stacks/#{stack.to_path}/container_logs", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['logs']).to eq([])
    end

    it 'returns logs' do
      container = test_app.containers.create(container_id: 'aa', name: 'app-1', host_node: node)
      container.container_logs.create!(
        type: 'stdout', data: 'foo', name: 'app-1', grid: grid, grid_service: test_app
      )
      get "/v1/stacks/#{stack.to_path}/container_logs", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['logs'].size).to eq(1)
    end
  end
end
