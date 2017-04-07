require_relative '../../spec_helper'


describe '/v1/volumes' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let! :grid do
    grid = Grid.create!(name: 'terminal-a')
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid.users << user

    user
  end

  let(:john) do
    User.create!(email: 'david@domain.com', external_id: '123456')
  end

  let(:johns_token) do
    AccessToken.create!(user: john, scopes: ['user'])
  end


  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  let! :stack do
    grid.stacks.create!(
      name: 'teststack',
    )
  end

  let! :volume do
    Volume.create!(
      grid: grid,
      name: 'external-vol',
      driver: 'some-driver',
      scope: 'node'
    )
  end

  let! :other_volume do
    Volume.create!(
      grid: grid,
      name: 'other-volume',
      driver: 'some-driver',
      scope: 'node'
    )
  end

  let! :node do
    HostNode.create!(
      grid: grid,
      name: 'node-1'
    )
  end

  describe 'GET /' do
    it 'returns all volumes' do
      get "/v1/volumes/#{grid.name}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['volumes'].size).to eq(2)
    end
  end

  describe 'GET /:id' do
    it 'returns volume json' do
      volume.volume_instances.create!(name: 'foo', host_node: node)
      redis = GridServices::Create.run(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          volumes: [
            "#{volume.name}:/data:ro"
          ]
      ).result

      get "/v1/volumes/#{grid.name}/#{volume.name}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response.keys.sort).to eq(%w(
        id created_at updated_at driver driver_opts name scope instances services
      ).sort)
      expect(json_response['id']).to eq("#{grid.name}/#{volume.name}")
      expect(json_response['driver']).to eq(volume.driver)
      expect(json_response['scope']).to eq(volume.scope)
      expect(json_response['instances'].first['node']).to eq(node.name)
      expect(json_response['instances'].first['name']).to eq('foo')
      expect(json_response['services']).to eq([{'id' => redis.to_path}])
    end

    it 'return 404 for non existing volume' do
      get "/v1/volumes/#{grid.name}/foo", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'return 404 for non existing grid' do
      get "/v1/volumes/foo/#{volume.name}", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'requires auth' do
      get "/v1/volumes/#{grid.name}/#{volume.name}", nil
      expect(response.status).to eq(403)
    end

    it 'returns 403 without grid access' do
      # John is not a user in this grid
      get "/v1/volumes/#{grid.name}/#{volume.name}", nil, { 'HTTP_AUTHORIZATION' => "Bearer #{johns_token.token_plain}"}
      expect(response.status).to eq(403)
    end
  end


  describe 'POST' do
    it 'creates new volume' do
      data = {
        name: 'foo',
        scope: 'instance',
        driver: 'local',
        driver_opts: {
          foo: 'bar'
        }
      }
      expect {
        post "/v1/volumes/#{grid.name}", data.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ Volume.count }.by(1)
      expect(Volume.find_by(name: 'foo').driver_opts['foo']).to eq('bar')
    end
  end

  describe 'DELETE' do
    it 'deletes volume' do
      expect {
        delete "/v1/volumes/#{grid.name}/#{volume.name}", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{Volume.count}. by (-1)

    end

    it 'returns 422 when volume still used by some service' do
      outcome = GridServices::Create.run(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          volumes: [
            "#{volume.name}:/data:ro"
          ]
      )

      expect {
        delete "/v1/volumes/#{grid.name}/#{volume.name}", nil, request_headers
        expect(response.status).to eq(422)
      }.not_to change{Volume.count}
    end
  end


end
