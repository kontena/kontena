
describe '/v1/grids/:grid/stacks', celluloid: true do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let(:grid) do
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

  let(:services) do
    [
      {name: 'redis', image: 'redis:3', stateful: true}
    ]
  end

  let(:valid_stack) do
    {
      name: 'test-stack',
      stack: 'my/test-stack',
      version: '0.1.0',
      registry: 'file://',
      source: '..',
      services: services
    }
  end

  let(:stack_with_volumes) do
    {
      name: 'test-stack',
      stack: 'my/test-stack',
      version: '0.1.0',
      registry: 'file://',
      source: '..',
      services: services,
      volumes: [
        { name: 'vol1', external: 'someVolume'}
      ]
    }
  end

  describe 'POST' do
    it 'creates new stack' do
      data = {
        name: 'test-stack',
        services: services
      }
      expect {
        post "/v1/grids/#{grid.name}/stacks", valid_stack.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ grid.reload.stacks.count }.by(1)
    end

    it 'creates audit event' do
      expect {
        post "/v1/grids/#{grid.name}/stacks", valid_stack.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ AuditLog.count }.by(1)
    end

    it 'creates new stack revision' do
      expect {
        post "/v1/grids/#{grid.name}/stacks", valid_stack.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ StackRevision.count }.by(1)
    end

    it 'creates new stack with volumes' do
      volume = Volume.create(name: 'someVolume', grid: grid, scope: 'grid')
      expect {
        post "/v1/grids/#{grid.name}/stacks", stack_with_volumes.to_json, request_headers
        expect(response.status).to eq(201)
      }.not_to change{ Volume.count }
    end

    it 'fails to create new stack with volumes when external volume does not exist' do
      expect {
        post "/v1/grids/#{grid.name}/stacks", stack_with_volumes.to_json, request_headers
        expect(response.status).to eq(422)
      }.to change{ Volume.count }.by(0)
    end

    it 'returns 422 error if services is empty' do
      valid_stack[:services] = []
      post "/v1/grids/#{grid.name}/stacks", valid_stack.to_json, request_headers
      expect(response.status).to eq(422)
    end

    it 'return 422 for service validation failure' do
      valid_stack[:services] = [
        {
          name: 'app',
          image: 'my/app:latest'
          # stateful parameter missing
        }
      ]
      expect {
        post "/v1/grids/#{grid.name}/stacks", valid_stack.to_json, request_headers
        expect(response.status).to eq(422)
      }.to change{ grid.reload.stacks.count }.by(0)
    end
  end
end
