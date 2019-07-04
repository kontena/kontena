
describe '/v1/stacks', celluloid: true do

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
      labels: ['fqdn=spaces.cim'],
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
      labels: ['fqdn=xyz.yo'],
      services: [
        { name: 'app2', image: 'my/app:latest', stateful: false },
        { name: 'redis', image: 'redis:2.8', stateful: true }
      ]
    )
    outcome.result
  end


  let(:expected_attributes) do
    %w(id created_at updated_at name stack version revision metadata
    services state expose source variables registry parent children labels)
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

    it 'includes assigned labels' do
      get "/v1/stacks/#{stack.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['labels']).to eq(['fqdn=spaces.cim'])
    end

    it 'returns 404 for unknown stack' do
      get "/v1/stacks/#{grid.name}/unknown-stack", nil, request_headers
      expect(response.status).to eq(404)
    end

    context 'stacks with metadata' do
      let!(:metastack) do
        outcome = Stacks::Create.run(
          current_user: david,
          grid: grid,
          name: 'metastack',
          stack: 'metastack',
          parent_name: nil,
          version: '0.1.0',
          source: '...',
          variables: { foo: 'bar' },
          registry: 'file',
          services: [
            { name: 'redis', image: 'redis:2.8', stateful: false }
          ],
          metadata: {
            tags: %w(tag1 tag2)
          }
        )
        outcome.result
      end

      it 'returns stack json including metadata' do
        get "/v1/stacks/#{metastack.to_path}", nil, request_headers
        expect(json_response['metadata']).to match hash_including(
          'tags' => array_including('tag1', 'tag2')
        )
      end
    end

    context 'nested stacks' do

      let!(:child_stack_1) do
        outcome = Stacks::Create.run(
          current_user: david,
          grid: grid,
          name: 'child-stack-1',
          stack: 'another-stack',
          parent_name: stack.name,
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

      let!(:child_stack_1_2) do
        outcome = Stacks::Create.run(
          current_user: david,
          grid: grid,
          name: 'child-stack-1-2',
          stack: 'another-stack',
          parent_name: child_stack_1.name,
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

      let!(:child_stack_2) do
        outcome = Stacks::Create.run(
          current_user: david,
          grid: grid,
          name: 'child-stack-2',
          stack: 'another-stack',
          parent_name: stack.name,
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

      it 'returns stack json including parent names' do
        get "/v1/stacks/#{child_stack_1.to_path}", nil, request_headers
        expect(json_response['parent']).to match hash_including('name' => stack.name, 'id' => "#{stack.grid.name}/#{stack.name}")
      end

      context 'when parent stack does not exist' do
        it 'returns stack json with parent name excluding parent id' do
          child_stack_1.destroy
          get "/v1/stacks/#{child_stack_1_2.to_path}", nil, request_headers
          expect(json_response['parent']).to match hash_including('name' => 'child-stack-1', 'id' => nil)
        end
      end

      it 'returns stack json including children names' do
        get "/v1/stacks/#{stack.to_path}", nil, request_headers
        expect(json_response['children']).to match array_including(
          hash_including('name' => child_stack_1.name, 'id' => "#{child_stack_1.grid.name}/#{child_stack_1.name}"),
          hash_including('name' => child_stack_2.name, 'id' => "#{child_stack_2.grid.name}/#{child_stack_2.name}"),
        )
        get "/v1/stacks/#{child_stack_1.to_path}", nil, request_headers
        remove_instance_variable(:@json_response)
        expect(json_response['children']).to match [ hash_including('name' => child_stack_1_2.name, 'id' => "#{child_stack_1_2.grid.name}/#{child_stack_1_2.name}") ]
      end
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

  describe 'PATCH /:name' do
    it 'saves non-empty stack labels' do
      labels = ['foo=bar', 'timezone=PDT']
      expect{
        patch "/v1/stacks/#{stack.to_path}", {labels: labels}.to_json, request_headers
        expect(response.status).to eq(200)
        expect(json_response['labels']).to eq labels
      }.to change{ stack.reload.labels }.from(['fqdn=spaces.cim']).to(labels)
    end

    it 'saves empty stack labels' do
      labels = []
      expect {
        patch "/v1/stacks/#{stack.to_path}", {labels: labels}.to_json, request_headers
        expect(response.status).to eq(200)
        expect(json_response['labels']).to eq labels
      }.to change{ stack.reload.labels }.from(["fqdn=spaces.cim"]).to(labels)
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
        labels: ['foo=1', 'bar=2'],
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
        .and change{ stack.reload.labels }.from(["fqdn=spaces.cim"]).to(['foo=1', 'bar=2'])
    end

    it 'returns 404 for unknown stack' do
      put "/v1/stacks/#{grid.name}/foobar", {}.to_json, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'DELETE /:name' do
    let(:stack_remove_worker) { instance_double(StackRemoveWorker) }
    let(:stack_remove_worker_async) { instance_double(StackRemoveWorker) }

    before do
      allow_any_instance_of(Stacks::Delete).to receive(:worker).with(:stack_remove).and_return(stack_remove_worker)
      allow(stack_remove_worker).to receive(:async).and_return(stack_remove_worker_async)
    end

    it 'deletes stack' do
      expect(stack_remove_worker_async).to receive(:perform).with(stack.id)
      delete "/v1/stacks/#{stack.to_path}", nil, request_headers
      expect(response.status).to eq(200)
    end

    it 'returns 404 for unknown stack' do
      put "/v1/stacks/#{grid.name}/foobar", {}.to_json, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'POST /:name/deploy' do
    let(:stack_deploy_worker) { instance_double(StackDeployWorker) }
    let(:stack_deploy_worker_async) { instance_double(StackDeployWorker) }

    before do
      allow_any_instance_of(Stacks::Deploy).to receive(:worker).with(:stack_deploy).and_return(stack_deploy_worker)
      allow(stack_deploy_worker).to receive(:async).and_return(stack_deploy_worker_async)
      allow(stack_deploy_worker_async).to receive(:perform)
    end

    it 'deploys stack services' do
      expect {
        post "/v1/stacks/#{stack.to_path}/deploy", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{ StackDeploy.count }.by(1)
    end

    it 'returns stack deploy id' do
      post "/v1/stacks/#{stack.to_path}/deploy", nil, request_headers
      expect(response.status).to eq(200)
      expect(StackDeploy.find(json_response['id'])).not_to be_nil
    end

    it 'deploy creates audit log' do
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

  describe 'POST /:id/stop' do
    it 'returns 200 when stop successful' do
      expect(Stacks::Stop).to receive(:run).once.and_return(double({:success? => true}))
      expect {
        post "/v1/stacks/#{stack.to_path}/stop", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{AuditLog.count}.by(1)
    end
    it 'returns 422 when stop fails' do
      expect(Stacks::Stop).to receive(:run).once.and_return(
        double({:success? => false, :errors => double({:message => 'boom'})}))
      expect {
        post "/v1/stacks/#{stack.to_path}/stop", nil, request_headers
        expect(response.status).to eq(422)
      }.to change{AuditLog.count}.by(0)
    end
  end

  describe 'POST /:id/restart' do
    it 'returns 200 when restart successful' do
      expect(Stacks::Restart).to receive(:run).once.and_return(double({:success? => true}))
      expect {
        post "/v1/stacks/#{stack.to_path}/restart", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{AuditLog.count}.by(1)
    end
    it 'returns 422 when restart fails' do
      expect(Stacks::Restart).to receive(:run).once.and_return(
        double({:success? => false, :errors => double({:message => 'error'})}))
      expect {
        post "/v1/stacks/#{stack.to_path}/restart", nil, request_headers
        expect(response.status).to eq(422)
      }.to change{AuditLog.count}.by(0)
    end
  end
end
