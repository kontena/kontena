require_relative '../../spec_helper'

describe '/v1/grids' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token}"
    }
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid = Grid.create!(name: 'Terminal A')
    grid.users << user

    user
  end

  let(:emily) do
    user = User.create!(email: 'emily@domain.com', external_id: '123457')
    grid = Grid.create!(name: 'Terminal B')
    grid.users << user

    user
  end

  let(:thomas) do
    user = User.create!(email: 'thomas@domain.com', external_id: '123458')
    grid = Grid.create!(name: 'Terminal C')
    grid.users << user

    user
  end

  let(:db_service) do
    grid  = david.grids.first
    GridService.create!(name: 'db', grid: grid, image_name: 'mysql:5.6')
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  describe 'POST' do
    it 'creates a new grid' do
      expect {
        post '/v1/grids', {}.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ david.reload.grids.count }.by(1)
    end

    it 'requires authorization' do
      request_headers.delete('HTTP_AUTHORIZATION')
      post '/v1/grids', {}.to_json, request_headers
      expect(response.status).to eq(403)
    end

    it 'requires valid name' do
      post '/v1/grids', {name: '1'}.to_json, request_headers
      expect(response.status).to eq(422)
      expect(json_response['error'])
    end

    it 'creates audit log entry' do
      expect {
        post '/v1/grids', {}.to_json, request_headers
      }.to change{ AuditLog.count }.by(1)
      audit_log = AuditLog.last
      grid = david.reload.grids.last
      expect(audit_log.event_name).to eq('create')
      expect(audit_log.resource_id).to eq(grid.id.to_s)
      expect(audit_log.grid).to eq(grid)
    end

    describe '/:id/services' do
      it 'creates a new service' do
        grid = david.grids.first
        payload = {
            image: 'foo/bar',
            stateful: false,
            name: 'foo-service'
        }
        expect {
          post "/v1/grids/#{grid.id}/services", payload.to_json, request_headers
          expect(response.status).to eq(201)
        }.to change{ grid.grid_services.count }.by(1)
      end

      it 'creates grid_service_links' do
        grid = david.grids.first
        payload = {
            image: 'wordpress',
            stateful: false,
            name: 'wordpress',
            links: [{'name' => "#{db_service.name}", 'alias' => 'mysql'}]
        }

        post "/v1/grids/#{grid.id}/services", payload.to_json, request_headers

        expect(json_response['links'].size).to eq(1)
        expect(json_response['links'].first['grid_service_id']).to eq(db_service.id.to_s)
        expect(json_response['links'].first['alias']).to eq('mysql')
      end
    end

  end

  describe 'GET /:id' do
    it 'returns grid' do
      grid = david.grids.first
      get "/v1/grids/#{grid.id}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['id']).to eq(grid.id.to_s)
    end

    describe '/services' do
      it 'returns grid services' do
        grid = david.grids.first
        grid.grid_services.create!(name: 'foo', image_name: 'foo/bar')
        get "/v1/grids/#{grid.id}/services", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['services'].size).to eq(1)
      end

      it 'does not show internal services' do
        grid = david.grids.first
        grid.grid_services.create!(name: 'foo', image_name: 'foo/bar')
        grid.grid_services.create!(name: 'vpn', image_name: 'kontena/openvpn:latest')
        grid.grid_services.create!(name: 'registry', image_name: 'registry:2.0')
        get "/v1/grids/#{grid.id}/services", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['services'].size).to eq(1)
      end
    end

    describe '/nodes' do
      it 'returns grid nodes' do
        grid = david.grids.first

        grid.host_nodes.create!(node_id: SecureRandom.uuid)
        get "/v1/grids/#{grid.id}/nodes", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['nodes'].size).to eq(1)
      end
    end

    describe '/users' do
      it 'returns grid users' do
        grid = david.grids.first
        get "/v1/grids/#{grid.id}/users", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response['users'].size).to eq(1)
      end
    end
  end

  describe 'POST /:id/users' do
    it 'validates that user belongs to grid' do
      grid = emily.grids.first
      post "/v1/grids/#{grid.id}/users", {email: david.email }.to_json, request_headers
      expect(response.status).to eq(404)
    end

    it 'requires existing email' do
      grid = david.grids.first
      post "/v1/grids/#{grid.id}/users", {email: 'invalid@domain.com'}.to_json, request_headers
      expect(response.status).to eq(422)
    end
    it 'assigns user to grid' do
      grid = david.grids.first
      post "/v1/grids/#{grid.id}/users", {email: emily.email}.to_json, request_headers
      expect(grid.reload.users.size).to eq(2)
      expect(emily.reload.grids.include?(grid)).to be_truthy
    end

    it 'creates audit log entry' do
      grid = david.grids.first
      expect {
        post "/v1/grids/#{grid.id}/users", {email: emily.email}.to_json, request_headers
      }.to change{ AuditLog.count }.by(1)
      audit_log = AuditLog.last
      expect(audit_log.event_name).to eq('assign user')
      expect(audit_log.resource_id).to eq(emily.id.to_s)
      expect(audit_log.grid).to eq(grid)
    end

    it 'returns array of grid users' do
      grid = david.grids.first
      post "/v1/grids/#{grid.id}/users", {email: emily.email}.to_json, request_headers
      expect(response.status).to eq(201)
      expect(json_response['users'].size).to eq(2)
    end

  end

  describe 'DELETE /:id/users/:email' do
    it 'validates that user belongs to grid' do
      grid = emily.grids.first
      delete "/v1/grids/#{grid.id}/users/#{emily.email}", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'validates that unassigned user belongs to grid' do
      grid = david.grids.first
      grid.users << thomas
      delete "/v1/grids/#{grid.id}/users/#{emily.email}", nil, request_headers
      expect(response.status).to eq(422)
    end

    it 'validates that user cannot remove last user from grid' do
      grid = david.grids.first

      delete "/v1/grids/#{grid.id}/users/#{david.email}", nil, request_headers
      expect(response.status).to eq(422)
    end

    it 'requires existing email' do
      grid = david.grids.first
      delete "/v1/grids/#{grid.id}/users/invalid@domain.com", nil, request_headers
      expect(response.status).to eq(422)
    end

    it 'unassigns user from grid' do
      grid = david.grids.first
      grid.users << emily
      delete "/v1/grids/#{grid.id}/users/#{emily.email}", nil, request_headers
      expect(grid.reload.users.size).to eq(1)
      expect(emily.reload.grids.include?(grid)).to be_falsey
    end

    it 'creates audit log entry' do
      grid = david.grids.first
      grid.users << emily
      expect {
        delete "/v1/grids/#{grid.id}/users/#{emily.email}", nil, request_headers
      }.to change{ AuditLog.count }.by(1)
      audit_log = AuditLog.last
      expect(audit_log.event_name).to eq('unassign user')
      expect(audit_log.resource_id).to eq(emily.id.to_s)
      expect(audit_log.grid).to eq(grid)
    end

    it 'returns array of grid users' do
      grid = david.grids.first
      grid.users << emily
      delete "/v1/grids/#{grid.id}/users/#{emily.email}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['users'].size).to eq(1)
    end

  end


  describe 'PUT /:id' do
    it 'requires authorization' do
      request_headers.delete('HTTP_AUTHORIZATION')
      grid = david.grids.first
      put "/v1/grids/#{grid.id}", {name: 'new name'}.to_json, request_headers
      expect(response.status).to eq(403)
    end

    it 'requires valid grid' do
      grid = double('random grid', id: '123456')
      put "/v1/grids/#{grid.id}", {name: 'ne'}.to_json, request_headers
      expect(response.status).to eq(404)
    end

    it 'requires valid name' do
      grid = david.grids.first
      put "/v1/grids/#{grid.id}", {name: 'ne'}.to_json, request_headers
      expect(response.status).to eq(422)
    end

    it 'updates grid with given name' do
      grid = david.grids.first
      put "/v1/grids/#{grid.id}", {name: 'new name'}.to_json, request_headers
      grid.reload
      expect(grid.name).to eq('new name')
    end

    it 'returns grid' do
      grid = david.grids.first
      put "/v1/grids/#{grid.id}", {name: 'new name'}.to_json, request_headers

      expect(response.status).to eq(200)
      expect(json_response['id']).to eq(grid.id.to_s)
    end

    it 'creates audit log entry' do
      grid = david.grids.first
      expect {
        put "/v1/grids/#{grid.id}", {name: 'new name'}.to_json, request_headers
      }.to change{ AuditLog.count }.by(1)
      audit_log = AuditLog.last
      expect(audit_log.event_name).to eq('update')
      expect(audit_log.resource_id).to eq(grid.id.to_s)
      expect(audit_log.grid).to eq(grid)
    end
  end

  describe 'DELETE /:id' do
    it 'requires authorization' do
      request_headers.delete('HTTP_AUTHORIZATION')
      grid = david.grids.first
      delete "/v1/grids/#{grid.id}", nil, request_headers
      expect(response.status).to eq(403)
    end

    it 'requires valid grid' do
      grid = double('random grid', id: '123456')
      delete "/v1/grids/#{grid.id}", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'destroys given grid' do
      grid = david.grids.first
      expect {
        delete "/v1/grids/#{grid.id}", nil, request_headers
      }.to change{Grid.count}.by(-1)
      expect(response.status).to eq(200)

      expect(Grid.where(id: grid.id).exists?).to be_falsey
    end

    it 'creates audit log entry' do
      grid = david.grids.first
      expect {
        delete "/v1/grids/#{grid.id}", nil, request_headers
      }.to change{ AuditLog.count }.by(1)
      audit_log = AuditLog.last
      expect(audit_log.event_name).to eq('delete')
      expect(audit_log.resource_id).to eq(grid.id.to_s)
    end

    context 'when grid has services' do
      it 'returns error' do
        grid = david.grids.first
        db_service
        expect {
          delete "/v1/grids/#{grid.id}", nil, request_headers
        }.to change{ Grid.count }.by(0)
        expect(response.status).to eq(422)
      end
    end
  end
end
