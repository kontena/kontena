require_relative '../../spec_helper'

describe '/v1/user/registries' do

  let(:valid_token) { AccessToken.create!(user: david, scopes: ['user']) }
  let(:request_headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token}" } }

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid = Grid.create!(name: 'Massive Grid')
    grid.users << user
    user
  end

  describe 'GET' do
    it 'returns emptya array when user does not have any registries' do
      get '/v1/user/registries', nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['registries']).to eq([])
    end

    it 'returns davids registry' do
      david.registries.create!(
          name: 'localhost:5000', url: 'https://localhost:5000/', username: 'foo', password: 'bar', email: david.email
      )
      get '/v1/user/registries', nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['registries'].size).to eq(1)
      expect(json_response['registries'][0]['name']).to eq('localhost:5000')
    end

    it 'requires authorization' do
      get '/v1/user/registries', nil
      expect(response.status).to eq(403)
    end
  end

  describe 'POST' do
    it 'adds registry' do
      data = {username: 'david', password: 'secret', email: david.email, url: 'https://index.docker.io/v1/'}
      expect {
        post '/v1/user/registries', data.to_json, request_headers
      }.to change{ david.registries.count }.by(1)

      expect(response.status).to eq(201)
    end

    it 'requires authorization' do
      data = {username: 'david', password: 'secret', email: david.email, url: 'https://index.docker.io/v1/'}
      post '/v1/user/registries', data.to_json
      expect(response.status).to eq(403)
    end
  end
end