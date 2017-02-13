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

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  let! :stack do
    grid.stacks.create!(
      name: 'teststack',
    )
  end


  let! :volume do
    stack.volumes.create!(
      grid: grid,
      name: 'test-vol',
      driver: 'some-driver',
      scope: 'node'
    )
  end

  describe 'GET /' do
    it 'returns all volumes' do
      get "/v1/volumes/#{grid.name}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['volumes'].size).to eq(1)
    end
  end

  describe 'GET /:id' do
    it 'returns volume json' do
      get "/v1/volumes/#{grid.name}/#{stack.name}/#{volume.name}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response.keys.sort).to eq(%w(
        id created_at updated_at driver driver_opts name scope stack
      ).sort)
      expect(json_response['id']).to eq("#{grid.name}/#{stack.name}/#{volume.name}")
      expect(json_response['driver']).to eq(volume.driver)
      expect(json_response['scope']).to eq(volume.scope)
    end

    it 'return 404 for non existing volume' do
      get "/v1/volumes/#{grid.name}/#{stack.name}/foo", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'return 404 for non existing stack' do
      get "/v1/volumes/#{grid.name}/foo/foo", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'return 404 for non existing grid' do
      get "/v1/volumes/foo/#{stack.name}/#{volume.name}", nil, request_headers
      expect(response.status).to eq(404)
    end
  end


  describe 'POST' do
    it 'creates new volume' do
      data = {
        name: 'foo',
        scope: 'node'
      }
      expect {
        post "/v1/volumes/#{grid.name}/#{stack.name}", data.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ stack.volumes.count }.by(1)
    end
  end

  describe 'DELETE' do
    it 'deletes volume' do
      expect {
        delete "/v1/volumes/#{grid.name}/#{stack.name}/#{volume.name}", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{stack.volumes.count}. by (-1)

    end

    it 'returns 422 when volume still used by some service' do
      redis = stack.grid_services.create!(
        grid: grid,
        name: 'redis',
        image_name: 'redis:2.8',
        volumes: ['test-vol:/data']
      )

      expect {
        delete "/v1/volumes/#{grid.name}/#{stack.name}/#{volume.name}", nil, request_headers
        expect(response.status).to eq(422)
      }.not_to change{stack.volumes.count}
    end
  end


end
