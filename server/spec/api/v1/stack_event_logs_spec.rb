
describe '/v1/stacks/:id/event_ogs', celluloid: true do

  let(:grid) do
    Grid.create!(name: 'terminal-a')
  end

  let(:stack) { grid.stacks.create(name: 'test') }
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
      get "/v1/stacks/#{stack.to_path}/event_logs"
      expect(response.status).to eq(403)
    end

    it 'returns empty array when no log items exist' do
      get "/v1/stacks/#{stack.to_path}/event_logs", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['logs']).to eq([])
    end

    it 'returns stack logs' do
      grid.event_logs.create(
        host_node: node,
        msg: 'hello world from node (not related to stack)',
        severity: EventLog::INFO
      )
      grid.event_logs.create(
        stack: stack,
        grid_service: test_app,
        host_node: node,
        msg: 'hello world',
        severity: EventLog::INFO
      )
      get "/v1/stacks/#{stack.to_path}/event_logs", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['logs'].size).to eq(1)
    end
  end
end
