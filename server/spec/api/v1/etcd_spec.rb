
describe '/v1/etcd/:grid_name/:etcd_path' do

  let(:valid_token) { AccessToken.create!(user: david, scopes: ['user']) }
  let(:request_headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}" } }

  let(:david) do
    User.create!(email: 'david@domain.com', external_id: '123456')
  end

  let(:grid) do
    grid = Grid.create!(name: 'test-grid')
    grid.users << david
    grid.create_node!('node-a', node_id: 'aaa', connected: true)
    grid
  end

  let(:fake_client) { spy(:rpc_client) }

  before(:each) do
    allow_any_instance_of(HostNode).to receive(:rpc_client).and_return(fake_client)
  end

  describe 'GET' do
    it 'gets etcd value via rpc client' do
      expect(fake_client).to receive(:request)
        .with('/etcd/get', '/foo/bar', {}).and_return({value: 'baz'})
      get "/v1/etcd/#{grid.name}//foo/bar", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['value']).to eq('baz')
    end

    it 'returns not found error if nodes are not connected' do
      grid.host_nodes.first.update_attribute(:connected, false)

      get "/v1/etcd/#{grid.name}//foo/bar", nil, request_headers
      expect(response.status).to eq(404)
      expect(json_response['error']).to include("Not connected")
    end
  end

  describe 'POST' do
    it 'sets etcd value via rpc client' do
      expect(fake_client).to receive(:request)
        .with('/etcd/set', '/foo/bar', {value: 'baz'}).and_return({value: 'baz'})
      post "/v1/etcd/#{grid.name}//foo/bar", {value: 'baz'}.to_json, request_headers
      expect(response.status).to eq(200)
      expect(json_response['value']).to eq('baz')
    end
  end

  describe 'DELETE' do
    it 'removes etcd value via rpc client' do
      expect(fake_client).to receive(:request)
        .with('/etcd/delete', '/foo/bar', {recursive: false}).and_return({value: 'baz'})
      delete "/v1/etcd/#{grid.name}//foo/bar", {}, request_headers
      expect(response.status).to eq(200)
    end

    it 'removes etcd key recursively via rpc client' do
      expect(fake_client).to receive(:request)
        .with('/etcd/delete', '/foo/bar', {recursive: true}).and_return({value: 'baz'})
      delete "/v1/etcd/#{grid.name}//foo/bar", {recursive: true}.to_json, request_headers
      expect(response.status).to eq(200)
    end
  end
end
