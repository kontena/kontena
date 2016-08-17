require_relative '../../spec_helper'

describe '/v1/stacks' do

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let(:grid) do
    grid = Grid.create!(name: 'terminal-a')
    grid
  end

  let(:stack) do
    stack = Stack.create(name: 'stack', grid: grid)
    app = GridService.create!(
      grid: david.grids.first,
      name: 'app',
      image_name: 'my/app:latest',
      stateful: false,
      stack: stack
    )
    redis = GridService.create!(
      grid: david.grids.first,
      name: 'redis',
      image_name: 'redis:2.8',
      stateful: true,
      stack: stack
    )
    grid.stacks << stack
    stack
  end

  let(:another_stack) do
    s = Stack.create(name: 'another-stack', grid: grid)
    app = GridService.create!(
      grid: david.grids.first,
      name: 'app2',
      image_name: 'my/app:latest',
      stateful: false,
      stack: s
    )
    redis = GridService.create!(
      grid: david.grids.first,
      name: 'redis2',
      image_name: 'redis:2.8',
      stateful: true,
      stack: s
    )
    grid.stacks << s
    s
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid.users << user

    user
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  describe 'GET /:name' do
    it 'returns stack json' do
      get "/v1/stacks/#{grid.name}/#{stack.name}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response.keys.sort).to eq(%w(
        id created_at updated_at name version grid_services state
      ).sort)
      expect(json_response['grid_services'].size).to eq(2)
      expect(json_response['grid_services'][0].keys.sort).to eq(%w(
        id name
      ).sort)
      
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
      get "/v1/stacks/#{grid.name}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['stacks'].size).to eq(2)
      expect(json_response['stacks'][0].keys.sort).to eq(%w(
        id created_at updated_at name version grid_services state
      ).sort)
      expect(json_response['stacks'][0]['grid_services'].size).to eq(2)
      expect(json_response['stacks'][0]['grid_services'][0].keys.sort).to eq(%w(
        id name
      ).sort)
    end

  end

  describe 'POST /' do
    it 'creates new empty stack' do
      expect {
        post "/v1/stacks/#{grid.name}", {name: 'test-stack'}.to_json, request_headers
        expect(response.status).to eq(201)
        expect(json_response.keys.sort).to eq(%w(
          id created_at updated_at name version grid_services state
        ).sort)
      }.to change{ grid.reload.stacks.count }.by(1)
    end

    it 'creates audit event' do
      expect {
        post "/v1/stacks/#{grid.name}", {name: 'test-stack'}.to_json, request_headers
        expect(response.status).to eq(201)
        expect(json_response.keys.sort).to eq(%w(
          id created_at updated_at name version grid_services state
        ).sort)
      }.to change{ AuditLog.count }.by(1)
    end

    it 'creates new stack with services' do
      data = {
        name: 'test-stack',
        services: [
          {
            name: 'app',
            image: 'my/app:latest',
            stateful: false
          }
        ]
      }
      expect {
        post "/v1/stacks/#{grid.name}", data.to_json, request_headers
        expect(response.status).to eq(201)
        expect(json_response['grid_services'].size).to eq(1)
      }.to change{ grid.reload.stacks.count }.by(1)
    end

    it 'return 422 for service validation failure' do
      data = {
        name: 'test-stack',
        services: [
          {
            name: 'app',
            image: 'my/app:latest'
            # stateful parameter missing
          }
        ]
      }
      expect {
        post "/v1/stacks/#{grid.name}", data.to_json, request_headers
        expect(response.status).to eq(422)
      }.to change{ grid.reload.stacks.count }.by(0)
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
      outcome = spy
      allow(outcome).to receive(:success?).and_return(true)
      allow(outcome).to receive(:result).and_return(stack)
      expect(Stacks::Update).to receive(:run).and_return(outcome)
      expect {
        put "/v1/stacks/#{grid.name}/#{stack.name}", data.to_json, request_headers
        expect(response.status).to eq(200)  
      }.to change{ AuditLog.count }.by(1)
    end

    it 'returns 404 for unknown stack' do
      put "/v1/stacks/#{grid.name}/foobar", {}.to_json, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'DELETE /:name' do

    it 'deletes stack' do
      outcome = spy
      allow(outcome).to receive(:success?).and_return(true)
      allow(Stacks::Delete).to receive(:run).and_return(outcome)
      
      expect {
        delete "/v1/stacks/#{grid.name}/#{stack.name}", nil, request_headers
        expect(response.status).to eq(200)  
      }.to change{ AuditLog.count }.by(1)      
    end

    it 'return 422 for stack already terminated' do
      stack.state = :terminated
      stack.save
      delete "/v1/stacks/#{grid.name}/#{stack.name}", nil, request_headers
      expect(response.status).to eq(422)
    end

    it 'returns 404 for unknown stack' do
      put "/v1/stacks/#{grid.name}/foobar", {}.to_json, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'POST /:name/deploy' do
    it 'deploys stack services' do
      outcome = spy
      allow(outcome).to receive(:success?).and_return(true)
      expect(GridServices::Deploy).to receive(:run).exactly(2).times.and_return(outcome)
      expect {
        post "/v1/stacks/#{grid.name}/#{stack.name}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{stack.reload.deployed?}.to(true)
    end

    it 'deploy creates audit log' do
      outcome = spy
      allow(outcome).to receive(:success?).and_return(true)
      expect(GridServices::Deploy).to receive(:run).exactly(2).times.and_return(outcome)
      expect {
        post "/v1/stacks/#{grid.name}/#{stack.name}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{AuditLog.count}.by(1)
    end
  end

end
