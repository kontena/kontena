
describe '/v1/grids/:name/external_registries' do

  let(:valid_token) { AccessToken.create!(user: david, scopes: ['user']) }
  let(:request_headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}" } }

  let(:david) do
    User.create!(email: 'david@domain.com', external_id: '123456')
  end

  let(:grid) do
    grid = Grid.create!(name: 'massive-grid')
    grid.users << david
    grid
  end

  describe 'GET' do
    it 'returns empty array when grid does not have any registries' do
      get "/v1/grids/#{grid.to_path}/external_registries", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['external_registries']).to eq([])
    end

    it 'returns davids registry' do
      grid.registries.create!(
          name: 'localhost:5000', url: 'https://localhost:5000/', username: 'foo', password: 'bar', email: david.email
      )
      get "/v1/grids/#{grid.to_path}/external_registries", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['external_registries'].size).to eq(1)
      expect(json_response['external_registries'][0]['name']).to eq('localhost:5000')
    end

    it 'requires authorization' do
      get "/v1/grids/#{grid.to_path}/external_registries", nil
      expect(response.status).to eq(403)
      get "/v1/grids/#{grid.to_path}/external_registries", nil, request_headers
      expect(response.status).to eq(200)
    end
  end

  describe 'POST' do
    it 'adds registry' do
      data = {username: 'david', password: 'secret', email: david.email, url: 'https://index.docker.io/v1/'}
      expect {
        post "/v1/grids/#{grid.to_path}/external_registries", data.to_json, request_headers
      }.to change{ grid.registries.count }.by(1)

      expect(response.status).to eq(201)
    end

    it 'requires authorization' do
      data = {username: 'david', password: 'secret', email: david.email, url: 'https://index.docker.io/v1/'}
      post "/v1/grids/#{grid.to_path}/external_registries", data.to_json
      expect(response.status).to eq(403)
    end
  end
end

describe '/v1/external_registries/:grid/:name' do
  let(:valid_token) { AccessToken.create!(user: david, scopes: ['user']) }
  let(:request_headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}" } }

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')

    user
  end

  let(:grid) do
    grid = Grid.create!(name: 'massive-grid')
    grid.users << david
    grid
  end

  describe 'DELETE' do
    it 'deletes registry from grid' do
      registry = grid.registries.create!(
          name: 'localhost:5000', url: 'https://localhost:5000/', username: 'foo', password: 'bar', email: david.email
      )
      expect {
        delete "/v1/external_registries/#{registry.to_path}", nil, request_headers
      }.to change{ grid.registries.count }.by(-1)

      expect(response.status).to eq(200)
    end
  end
end
