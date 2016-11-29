require_relative '../../spec_helper'

describe '/v1/grids' do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }
  let(:grid) { Grid.create!(name: 'test') }
  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid.users << user

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

  describe 'GET' do
    it 'returns node with valid id and token' do
      node = grid.host_nodes.create!(name: 'abc', node_id: 'a:b:c')
      get "/v1/nodes/#{node.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['id']).to eq('a:b:c')
    end

    it 'returns error with invalid id' do
      get "/v1/nodes/#{grid.name}/foo", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'returns error with invalid token' do
      node = grid.host_nodes.create!(name: 'abc', node_id: 'a:b:c')
      get "/v1/nodes/#{node.to_path}", nil, {}
      expect(response.status).to eq(403)
    end
  end

  describe 'PUT' do
    it 'saves node labels' do
      node = grid.host_nodes.create!(name: 'abc', node_id: 'a:b:c')
      labels = ['foo=1', 'bar=2']
      put "/v1/nodes/#{node.to_path}", {labels: labels}.to_json, request_headers
      expect(response.status).to eq(200)
      expect(node.reload.labels).to eq(labels)
    end

    it 'returns error with invalid id' do
      put "/v1/nodes/#{grid.name}/abc", {labels: []}.to_json, request_headers
      expect(response.status).to eq(404)
    end

    it 'returns error with invalid token' do
      node = grid.host_nodes.create!(name: 'abc', node_id: 'a:b:c')
      put "/v1/nodes/#{node.to_path}", {labels: []}.to_json, {}
      expect(response.status).to eq(403)
    end
  end
end
