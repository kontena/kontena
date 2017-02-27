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

  let(:legacy_request_headers) do
    {
        'HTTP_KONTENA_GRID_TOKEN' => "#{grid.token}"
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

  describe 'GET /health' do
    let :node do
      grid.host_nodes.create!(name: 'abc', node_id: 'a:b:c')
    end

    let :rpc_client do
      instance_double(RpcClient)
    end

    before do
      allow_any_instance_of(HostNode).to receive(:rpc_client).and_return(rpc_client)
    end

    it "returns etcd health when RPC returns health" do
      expect(rpc_client).to receive(:request).with('/etcd/health').and_return({health: true})
      get "/v1/nodes/#{node.to_path}/health", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['etcd_health']).to eq({'health' => true, 'error' => nil})
    end

    it "returns etcd error when RPC returns error" do
      expect(rpc_client).to receive(:request).with('/etcd/health').and_return({error: "unhealthy"})
      get "/v1/nodes/#{node.to_path}/health", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['etcd_health']).to eq({'health' => nil, 'error' => "unhealthy"})
    end

    it "returns HTTP error when RPC fails" do
      expect(rpc_client).to receive(:request).with('/etcd/health').and_raise(RpcClient::TimeoutError.new(503, "timeout"))
      get "/v1/nodes/#{node.to_path}/health", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['etcd_health']).to eq({'health' => nil, 'error' => "timeout"})
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

  describe 'PUT (legacy)' do
    it 'saves node labels' do
      node = grid.host_nodes.create!(node_id: 'abc')
      labels = ['foo=1', 'bar=2']
      put '/v1/nodes/abc', {labels: labels}.to_json, legacy_request_headers
      expect(response.status).to eq(200)
      expect(node.reload.labels).to eq(labels)
    end

    it 'returns error with invalid id' do
      put '/v1/nodes/abc', {labels: []}.to_json, legacy_request_headers
      expect(response.status).to eq(404)
    end

    it 'returns error with invalid token' do
      grid.host_nodes.create!(node_id: 'abc')
      put '/v1/nodes/abc', {labels: []}.to_json, {}
      expect(response.status).to eq(404)
    end
  end
end
