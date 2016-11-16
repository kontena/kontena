require_relative '../../spec_helper'

describe '/v1/grids/:grid/stacks' do

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

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid.users << user

    user
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  describe 'POST' do
    it 'creates new empty stack' do
      expect {
        data = { name: 'test-stack', services: [] }
        post "/v1/grids/#{grid.name}/stacks", data.to_json, request_headers
        expect(response.status).to eq(201)
        expect(json_response.keys.sort).to eq(%w(
          id created_at updated_at name version services state
        ).sort)
      }.to change{ grid.reload.stacks.count }.by(1)
    end

    it 'creates audit event' do
      expect {
        data = { name: 'test-stack', services: [] }
        post "/v1/grids/#{grid.name}/stacks", data.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ AuditLog.count }.by(1)
    end

    it 'creates new stack' do
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
        post "/v1/grids/#{grid.name}/stacks", data.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ grid.reload.stacks.count }.by(1)
    end

    it 'creates new stack revision' do
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
        post "/v1/grids/#{grid.name}/stacks", data.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ StackRevision.count }.by(1)
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
        post "/v1/grids/#{grid.name}/stacks", data.to_json, request_headers
        expect(response.status).to eq(422)
      }.to change{ grid.reload.stacks.count }.by(0)
    end
  end
end
