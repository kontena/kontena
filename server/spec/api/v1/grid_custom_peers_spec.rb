require_relative '../../spec_helper'

describe '/v1/grids/:name/custom_peers' do

  let(:david) do
    User.create!(email: 'david@domain.com', external_id: '123456')
  end
  let(:bob) do
    User.create!(email: 'bob@domain.com', external_id: 'asdasdasd')
  end

  let(:david_token) { AccessToken.create!(user: david, scopes: ['user']) }
  let(:bob_token) { AccessToken.create!(user: bob, scopes: ['user']) }
  let(:request_headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{david_token.token}" } }
  let(:bob_request_headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{bob_token.token}" } }

  let(:grid) do
    grid = Grid.create!(name: 'massive-grid')
    grid.users << david
    grid
  end

  describe 'POST' do
    it 'adds custom peer' do
      data = {peer: '192.168.121.22'}
      expect {
        post "/v1/grids/#{grid.to_path}/custom_peers", data.to_json, request_headers
      }.to change{ grid.reload.custom_peers.size }.by(1)
      expect(response.status).to eq(201)
    end

    it 'requires that user has access to grid' do
      data = {peer: '192.168.121.22'}
      post "/v1/grids/#{grid.to_path}/custom_peers", data.to_json, bob_request_headers
      expect(response.status).to eq(404)
    end

    it 'requires authorization' do
      data = {peer: '192.168.121.22'}
      post "/v1/grids/#{grid.to_path}/custom_peers", data.to_json
      expect(response.status).to eq(403)
    end
  end

  describe 'DELETE' do
    let(:peer) { '192.168.68.12' }
    before(:each) do
      grid.push(custom_peers: peer)
    end

    it 'deletes custom peer' do
      expect {
        delete "/v1/grids/#{grid.to_path}/custom_peers/#{peer}", nil, request_headers
      }.to change{ grid.reload.custom_peers.size }.by(-1)
      expect(response.status).to eq(200)
    end

    it 'requires that user has access to grid' do
      delete "/v1/grids/#{grid.to_path}/custom_peers/#{peer}", nil, bob_request_headers
      expect(response.status).to eq(404)
    end

    it 'requires authorization' do
      delete "/v1/grids/#{grid.to_path}/custom_peers/#{peer}", nil
      expect(response.status).to eq(403)
    end
  end
end
