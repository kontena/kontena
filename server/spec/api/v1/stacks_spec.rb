require_relative '../../spec_helper'

describe '/v1/stacks' do

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    user
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let(:grid) do
    grid = Grid.create!(name: 'terminal-a')
    grid.users << david
    grid
  end

  let(:stack) do
    outcome = Stacks::Create.run(
      current_user: david,
      grid: grid,
      name: 'stack',
      services: [
        { name: 'app', image: 'my/app:latest', stateful: false },
        { name: 'redis', image: 'redis:2.8', stateful: true }
      ]
    )
    outcome.result
  end

  let(:another_stack) do
    outcome = Stacks::Create.run(
      current_user: david,
      grid: grid,
      name: 'another-stack',
      services: [
        { name: 'app2', image: 'my/app:latest', stateful: false },
        { name: 'redis', image: 'redis:2.8', stateful: true }
      ]
    )
    outcome.result
  end

  describe 'GET /:name' do
    it 'returns stack json' do
      get "/v1/stacks/#{stack.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response.keys.sort).to eq(%w(
        id created_at updated_at name version services state expose
      ).sort)
      expect(json_response['services'].size).to eq(0)
    end

    it 'includes deployed services' do
      Stacks::Deploy.run(stack: stack, current_user: david)
      get "/v1/stacks/#{stack.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['services'].size).to eq(2)
      expect(json_response['services'][0].keys).to include('id', 'name')
    end

    it 'returns 404 for unknown stack' do
      get "/v1/stacks/#{grid.name}/unknown-stack", nil, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'GET /' do
    it 'returns stacks json' do
      stack
      another_stack
      get "/v1/grids/#{grid.name}/stacks", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['stacks'].size).to eq(grid.stacks.count)
      expect(json_response['stacks'][0].keys.sort).to eq(%w(
        id created_at updated_at name version services state expose
      ).sort)
    end

  end

  describe 'PUT /:name' do
    it 'updates stack' do
      data = {
        name: stack.name,
        services: [
          {
            name: 'app_xyz',
            image: 'my/app:latest',
            stateful: false
          }
        ]
      }
      expect {
        put "/v1/stacks/#{stack.to_path}", data.to_json, request_headers
        expect(response.status).to eq(200)
      }.to change{ stack.stack_revisions.count }.by(1)
    end

    it 'returns 404 for unknown stack' do
      put "/v1/stacks/#{grid.name}/foobar", {}.to_json, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'DELETE /:name' do
    it 'deletes stack' do
      stack
      expect {
        delete "/v1/stacks/#{stack.to_path}", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{ grid.stacks.count }.by(-1)
    end

    it 'returns 404 for unknown stack' do
      put "/v1/stacks/#{grid.name}/foobar", {}.to_json, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'POST /:name/deploy' do
    before(:each) do
      allow(GridServices::Deploy).to receive(:run).and_return(spy)
    end

    it 'deploys stack services' do
      expect {
        post "/v1/stacks/#{stack.to_path}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{ stack.grid_services.count }.by(2)
    end

    it 'deploy creates audit log' do
      expect {
        post "/v1/stacks/#{stack.to_path}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{AuditLog.count}.by(1)
    end
  end
end
