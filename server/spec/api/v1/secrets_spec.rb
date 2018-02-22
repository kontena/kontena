
describe 'secrets' do

  let(:request_headers) do
    { 'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}" }
  end

  let(:grid) do
    Grid.create!(name: 'big-one')
  end

  let(:another_grid) do
    Grid.create!(name: 'another-one')
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid.users << user
    user
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  describe 'POST /v1/grids/:grid/secrets' do
    it 'saves a new secret' do
      data = {name: 'PASSWD', value: 'secretzz'}
      expect {
        post "/v1/grids/#{grid.to_path}/secrets", data.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ grid.grid_secrets.count }.by(1)
    end

    it 'creates an audit entry' do
      data = {name: 'PASSWD', value: 'secretzz'}
      expect {
        post "/v1/grids/#{grid.to_path}/secrets", data.to_json, request_headers
      }.to change{ grid.audit_logs.count }.by(1)
    end

    it 'filters request body from audit entry' do
      data = {name: 'PASSWD', value: 'secretzz'}

      post "/v1/grids/#{grid.to_path}/secrets", data.to_json, request_headers
      entry = grid.audit_logs.last
      expect(entry.request_body).to be_nil
    end

    it 'returns error on duplicate name' do
      grid.grid_secrets.create!(name: 'PASSWD', value: 'aaaa')
      data = {name: 'PASSWD', value: 'secretzz'}
      post "/v1/grids/#{grid.to_path}/secrets", data.to_json, request_headers
      expect(response.status).to eq(422)
    end

    it 'returns error if user has no access to grid' do
      data = {name: 'PASSWD', value: 'secretzz'}
      post "/v1/grids/#{another_grid.to_path}/secrets", data.to_json, request_headers
      expect(response.status).to eq(403)
    end
  end

  describe 'PUT /v1/secrets/:grid/:name' do
    context 'when secret exists' do
      it 'updates a secret' do
        secret = grid.grid_secrets.create(name: 'FOO', value: 'supersecret')
        data = {value: 'secretzz'}
        expect {
          put "/v1/secrets/#{secret.to_path}", data.to_json, request_headers
          expect(response.status).to eq(200)
        }.to change{ secret.reload.value }.to('secretzz')
      end

      it 'creates an audit entry' do
        secret = grid.grid_secrets.create(name: 'FOO', value: 'supersecret')
        data = {value: 'secretzz'}
        expect {
          put "/v1/secrets/#{secret.to_path}", data.to_json, request_headers
        }.to change{ grid.audit_logs.count }.by(1)
      end

      it 'filters request body from audit entry' do
        secret = grid.grid_secrets.create!(name: 'FOO', value: 'supersecret')
        data = {value: 'secretzz'}
        put "/v1/secrets/#{secret.to_path}", data.to_json, request_headers
        expect(response.status).to eq(200)
        entry = grid.audit_logs.last
        expect(entry.request_body).to be_nil
      end
    end

    context 'when the secret does not exist' do
      it 'returns error' do
        data = {value: 'secretzz'}
        put "/v1/secrets/#{grid.name}/BAR", data.to_json, request_headers
        expect(response.status).to eq(404)
      end

      it 'creates a new secret if upsert requested' do
        data = {value: 'secretzz', upsert: true, name: 'FOO'}
        expect {
          put "/v1/secrets/#{grid.name}/FOO", data.to_json, request_headers
          expect(response.status).to eq(201)
        }.to change{ grid.grid_secrets.count }.by(1)
      end
    end

    it 'returns error if user has no access to grid' do
      secret = grid.grid_secrets.create(name: 'FOO', value: 'supersecret')
      data = {value: 'secretzz'}
      post "/v1/secrets/#{another_grid.name}/FOO", data.to_json, request_headers
      expect(response.status).to eq(403)
    end
  end

  describe 'GET /v1/grids/:grid/secrets' do
    it 'returns empty array if no secrets' do
      get "/v1/grids/#{grid.to_path}/secrets", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['secrets']).to eq([])
    end

    it 'returns secrets array' do
      grid.grid_secrets.create(name: 'foo', value: 'supersecret')
      grid.grid_services.create!(
        name: 'app',
        image_name: 'my/app:latest',
        stateful: false,
        secrets: [
          secret: 'foo',
          name: 'bar'
        ]
      )
      get "/v1/grids/#{grid.to_path}/secrets", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['secrets'].size).to eq(1)
      secret = json_response['secrets'][0]
      expect(secret.keys.sort).to eq(%w(id name created_at updated_at services).sort)
    end
  end

  describe 'GET /v1/secrets/:name' do
    it 'returns secret with value' do
      secret = grid.grid_secrets.create(name: 'foo', value: 'supersecret')
      get "/v1/secrets/#{secret.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['value']).to eq(secret.value)
    end

    it 'returns related services' do
      secret = grid.grid_secrets.create(name: 'foo', value: 'supersecret')
      service = grid.grid_services.create!(
        name: 'app',
        image_name: 'my/app:latest',
        stateful: false,
        secrets: [
          secret: 'foo',
          name: 'bar'
        ]
      )
      grid.grid_services.create!(
        name: 'worker',
        image_name: 'my/app:latest',
        stateful: false,
        secrets: [
          secret: 'foo2',
          name: 'bar'
        ]
      )
      get "/v1/secrets/#{secret.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['services'].count).to eq(1)
      expect(json_response['services']).to eq([{'id' => service.to_path, 'name' => 'app' }])
    end

    it 'creates an audit entry' do
      secret = grid.grid_secrets.create(name: 'foo', value: 'supersecret')
      expect {
        get "/v1/secrets/#{secret.to_path}", nil, request_headers
      }.to change{ grid.audit_logs.count }.by(1)
    end

    it 'returns error if user has no access to grid' do
      secret = another_grid.grid_secrets.create(name: 'foo', value: 'supersecret')
      get "/v1/secrets/#{secret.to_path}", nil, request_headers
      expect(response.status).to eq(403)
    end
  end

  describe 'DELETE /v1/secrets/:name' do
    it 'removes secret' do
      secret = grid.grid_secrets.create(name: 'foo', value: 'supersecret')
      expect {
        delete "/v1/secrets/#{secret.to_path}", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{ grid.grid_secrets.count }.by(-1)
    end

    it 'creates an audit entry' do
      secret = grid.grid_secrets.create(name: 'foo', value: 'supersecret')
      expect {
        delete "/v1/secrets/#{secret.to_path}", nil, request_headers
      }.to change{ grid.audit_logs.count }.by(1)
    end

    it 'returns error if user has no access to grid' do
      secret = another_grid.grid_secrets.create(name: 'foo', value: 'supersecret')
      delete "/v1/secrets/#{secret.to_path}", nil, request_headers
      expect(response.status).to eq(403)
    end
  end
end
