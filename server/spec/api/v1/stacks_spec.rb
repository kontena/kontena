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
      stack: 'stack',
      version: '0.1.1',
      source: '...',
      variables: { foo: 'bar' },
      registry: 'file',
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
      stack: 'another-stack',
      version: '0.2.1',
      source: '...',
      variables: { foo: 'bar' },
      registry: 'file',
      services: [
        { name: 'app2', image: 'my/app:latest', stateful: false },
        { name: 'redis', image: 'redis:2.8', stateful: true }
      ]
    )
    outcome.result
  end

  let(:expected_attributes) do
    %w(id created_at updated_at name stack version services state expose source variables registry)
  end

  describe 'GET /:name' do
    it 'returns stack json' do
      get "/v1/stacks/#{stack.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response.keys.sort).to eq(expected_attributes.sort)
      expect(json_response['services'].size).to eq(stack.latest_rev.services.size)
    end

    it 'includes deployed services' do
      mutation = Stacks::Deploy.new(stack: stack, current_user: david)
      allow(mutation).to receive(:deploy_stack)
      mutation.run
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
      expect(json_response['stacks'][0]['variables']['foo']).to eq 'bar'
      expect(json_response['stacks'].size).to eq(grid.stacks.count - 1)
      expect(json_response['stacks'][0].keys.sort).to eq(expected_attributes.sort)
    end
  end

  describe 'PUT /:name' do
    it 'updates stack' do
      data = {
        name: stack.name,
        stack: stack.latest_rev.stack_name,
        registry: stack.latest_rev.registry,
        source: stack.latest_rev.source,
        variables: stack.latest_rev.variables,
        version: stack.latest_rev.version,
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
    let(:worker_klass) do
      Class.new do
        include Celluloid
      end
    end

    let(:worker) do
      worker = worker_klass.new
      Celluloid::Actor[:stack_remove_worker] = worker
    end

    it 'deletes stack' do
      expect(worker.wrapped_object).to receive(:perform)
      delete "/v1/stacks/#{stack.to_path}", nil, request_headers
      expect(response.status).to eq(200)
    end

    it 'returns 404 for unknown stack' do
      put "/v1/stacks/#{grid.name}/foobar", {}.to_json, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'POST /:name/deploy' do

    let(:deploy_worker_klass) do
      Class.new do
        include Celluloid
      end
    end

    let(:deploy_worker) do
      worker = deploy_worker_klass.new
      Celluloid::Actor[:stack_deploy_worker] = worker
    end

    it 'deploys stack services' do
      allow(deploy_worker.wrapped_object).to receive(:async)
      expect {
        post "/v1/stacks/#{stack.to_path}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{ StackDeploy.count }.by(1)
    end

    it 'returns stack deploy id' do
      allow(deploy_worker.wrapped_object).to receive(:async)
      post "/v1/stacks/#{stack.to_path}/deploy", nil, request_headers
      expect(response.status).to eq(200)
      expect(StackDeploy.find(json_response['id'])).not_to be_nil
    end

    it 'deploy creates audit log' do
      allow(deploy_worker.wrapped_object).to receive(:async)
      expect {
        post "/v1/stacks/#{stack.to_path}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{AuditLog.count}.by(1)
    end
  end

  describe 'GET /:id/deploys/:deploy_id' do
    it 'returns deploy object' do
      deployment = stack.stack_deploys.create
      get "/v1/stacks/#{stack.to_path}/deploys/#{deployment.id}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['id']).to eq(deployment.id.to_s)
    end

    it 'returns 404 if deploy not found' do
      get "/v1/stacks/#{stack.to_path}/deploys/foo", nil, request_headers
      expect(response.status).to eq(404)
    end
  end
end
