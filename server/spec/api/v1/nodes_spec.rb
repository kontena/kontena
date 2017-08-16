
describe '/v1/nodes', celluloid: true do
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
    it 'returns node with valid id and has_token' do
      node = grid.create_node!('abc', node_id: 'a:b:c', token: 'asdfasdfasdfasdf')
      get "/v1/nodes/#{node.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response).to_not include 'token'
      expect(json_response).to match hash_including(
        'id' => 'test/abc',
        'node_id' => 'a:b:c',
        'has_token' => true,
      )
    end

    it 'returns node without has_token' do
      node = grid.create_node!('abc', node_id: 'a:b:c')
      get "/v1/nodes/#{node.to_path}", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response).to_not include 'token'
      expect(json_response).to match hash_including(
        'id' => 'test/abc',
        'node_id' => 'a:b:c',
        'has_token' => false,
      )
    end

    it 'returns error with invalid id' do
      get "/v1/nodes/#{grid.name}/foo", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'returns error with invalid token' do
      node = grid.create_node!('abc', node_id: 'a:b:c')
      get "/v1/nodes/#{node.to_path}", nil, {}
      expect(response.status).to eq(403)
    end
  end

  describe 'GET /token' do
    let(:node) do
      node = grid.create_node!('abc', token: 'asdfasdfasdfasdf')
    end

    it "returns 403 without admin role" do
      get "/v1/nodes/#{node.to_path}/token", nil, request_headers
      expect(response.status).to eq(403)
    end
  end

  describe 'PUT /token' do
    let(:node) do
      node = grid.create_node!('abc', token: 'asdfasdfasdfasdf')
    end

    it "returns 403 without admin role" do
      put "/v1/nodes/#{node.to_path}/token", nil, request_headers
      expect(response.status).to eq(403)
    end
  end

  describe 'DELETE /token' do
    let(:node) do
      node = grid.create_node!('abc', token: 'asdfasdfasdfasdf')
    end

    it "returns 403 without admin role" do
      delete "/v1/nodes/#{node.to_path}/token", {}.to_json, request_headers
      expect(response.status).to eq(403)
    end
  end

  context "for a user with an admin role" do
    before do
      david.roles << Role.create(name: 'grid_admin', description: 'Grid admin')
    end

    describe 'GET /token' do
      let(:node) do
        node = grid.create_node!('abc', token: 'asdfasdfasdfasdf')
      end

      it "returns node token" do
        get "/v1/nodes/#{node.to_path}/token", nil, request_headers
        expect(response.status).to eq(200)
        expect(json_response).to eq({
            'id' => 'test/abc',
            'token' => 'asdfasdfasdfasdf',
        })
      end

      it "returns 404 if node does not have a token" do
        node.token = nil
        node.save!

        get "/v1/nodes/#{node.to_path}/token", nil, request_headers
        expect(response.status).to eq(404)
      end
    end

    describe 'PUT /token' do
      let(:node) do
        node = grid.create_node!('abc', token: 'asdfasdfasdfasdf', connected: true)
      end

      it "generates new node token" do
        put "/v1/nodes/#{node.to_path}/token", { 'token' => nil }.to_json, request_headers
        expect(response.status).to eq(200)
        expect(json_response).to match({
            'id' => 'test/abc',
            'token' => String,
        })
        expect(json_response['token']).to_not eq 'asdfasdfasdfasdf'

        expect(node.reload).to be_connected
      end

      it "updates given token" do
        put "/v1/nodes/#{node.to_path}/token", { 'token' => 'asdfasdfasdfasdf2' }.to_json, request_headers
        expect(response.status).to eq(200)
        expect(json_response).to eq({
            'id' => 'test/abc',
            'token' => 'asdfasdfasdfasdf2',
        })
      end

      it "fails with empty token" do
        put "/v1/nodes/#{node.to_path}/token", { 'token' => '' }.to_json, request_headers
        expect(response.status).to eq(422)
        expect(json_response).to eq 'error' => { 'token' => "Token can't be blank" }
      end

      it "resets node connection" do
        expect{
          put "/v1/nodes/#{node.to_path}/token", { 'token' => 'asdfasdfasdfasdf2', 'reset_connection' => true }.to_json, request_headers
          expect(response.status).to eq(200)
        }.to change{node.reload.connected?}.from(true).to(false)

        expect(json_response).to eq({
            'id' => 'test/abc',
            'token' => 'asdfasdfasdfasdf2',
        })
      end
    end

    describe 'DELETE /token' do
      let(:node) do
        node = grid.create_node!('abc', token: 'asdfasdfasdfasdf', connected: true)
      end

      it "clears token with connection reset" do
        expect{
          delete "/v1/nodes/#{node.to_path}/token", { 'reset_connection' => true }.to_json, request_headers
        }.to change{node.reload.connected?}.from(true).to(false)

        expect(response.status).to eq(200)
        expect(json_response).to eq({})
      end
    end
  end

  describe 'GET /health' do
    let :node do
      grid.create_node!('abc', node_id: 'a:b:c', connected: true, updated: true)
    end

    let :rpc_client do
      instance_double(RpcClient)
    end

    before do
      allow_any_instance_of(HostNode).to receive(:rpc_client).and_return(rpc_client)
    end

    it "returns error when node is offline" do
      node.set(:connected => false)
      expect(rpc_client).to_not receive(:request)
      get "/v1/nodes/#{node.to_path}/health", nil, request_headers
      expect(response.status).to eq(422)
      expect(json_response).to match hash_including(
        'error' => { 'connection' => "Websocket is not connected" },
      )
    end

    it "returns etcd health when RPC returns health" do
      expect(rpc_client).to receive(:request).with('/etcd/health').and_return({health: true})
      get "/v1/nodes/#{node.to_path}/health", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response).to match hash_including(
        'name' => 'abc',
        'connected' => true,
        'status' => 'online',
        'etcd_health' => {'health' => true, 'error' => nil},
      )
    end

    it "returns etcd error when RPC returns error" do
      expect(rpc_client).to receive(:request).with('/etcd/health').and_return({error: "unhealthy"})
      get "/v1/nodes/#{node.to_path}/health", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response).to match hash_including(
        'name' => 'abc',
        'connected' => true,
        'status' => 'online',
        'etcd_health' => {'health' => nil, 'error' => "unhealthy"},
      )
    end

    it "returns error when RPC fails" do
      expect(rpc_client).to receive(:request).with('/etcd/health').and_raise(RpcClient::TimeoutError.new(503, "Timeout after 10.0s"))
      get "/v1/nodes/#{node.to_path}/health", nil, request_headers
      expect(response.status).to eq(422)
      expect(json_response).to match hash_including(
        'error' => { 'etcd_health' => "Timeout after 10.0s" },
      )
    end
  end

  describe 'GET /metrics' do
    let :node do
      grid.create_node!('abc', node_id: 'a:b:c')
    end

    before do
      node.host_node_stats.create!({
        grid_id: grid.id,
        memory: {
          total: 1000,
          used: 100,
          free: 900,
          active: 400,
          inactive: 600,
          cached: 40,
          buffers: 60
          },
          filesystem: [{
          total: 1000,
          used: 10
        }],
          cpu: {
          num_cores: 2,
          system: 5.5,
          user: 10.0
          },
        network: {
          internal: {
            interfaces: ["weave", "vethwe123"],
            rx_bytes: 400,
            rx_bytes_per_second: 400.5,
            tx_bytes: 200,
            tx_bytes_per_second: 200.5,
          },
          external: {
            interfaces: ["docker0"],
            rx_bytes: 500,
            rx_bytes_per_second: 500.5,
            tx_bytes: 510,
            tx_bytes_per_second: 510.5
          }
        }
      })
    end

    it 'returns recent metrics' do
      get "/v1/nodes/#{node.to_path}/metrics", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['stats'].size).to eq 1
      expect(json_response['stats'][0]['cpu']).to eq({ 'used' => 15.5, 'cores' => 2 })
      expect(json_response['stats'][0]['filesystem']).to eq({ 'used' => 10.0, 'total' => 1000.0 })
      expect(json_response['stats'][0]['memory']).to eq({
        'used' => 100.0,
        'total' => 1000.0,
        'free' => 900.0,
        'active' => 400.0,
        'inactive' => 600.0,
        'cached' => 40.0,
        'buffers' => 60.0
      })
      expect(json_response['stats'][0]['network']['internal']).to eq({
        'interfaces' => ["weave", "vethwe123"],
        'rx_bytes' => 400.0,
        'rx_bytes_per_second' => 400.5,
        'tx_bytes' => 200.0,
        'tx_bytes_per_second' => 200.5 })
        expect(json_response['stats'][0]['network']['external']).to eq({
          'interfaces' => ["docker0"],
          'rx_bytes' => 500.0,
          'rx_bytes_per_second' => 500.5,
          'tx_bytes' => 510.0,
          'tx_bytes_per_second' => 510.5 })
    end

    it 'applies date filters' do
      from = Time.parse("2017-01-01 12:00:00 +00:00").utc
      to = Time.parse("2017-01-01 12:15:00 +00:00").utc
      get "/v1/nodes/#{node.to_path}/metrics?from=#{from}&to=#{to}", nil, request_headers

      expect(response.status).to eq(200)
      expect(json_response['stats'].size).to eq 0
      expect(Time.parse(json_response['from'])).to eq from
      expect(Time.parse(json_response['to'])).to eq to
    end
  end

  describe 'PUT' do
    it 'saves node labels' do
      node = grid.create_node!('abc', node_id: 'a:b:c')
      labels = ['foo=1', 'bar=2']
      put "/v1/nodes/#{node.to_path}", {labels: labels}.to_json, request_headers
      expect(response.status).to eq(200)
      expect(node.reload.labels).to eq(labels)
    end

    it 'saves availability' do
      node = grid.create_node!('abc', node_id: 'a:b:c', labels: ['foo=bar'])
      put "/v1/nodes/#{node.to_path}", {availability: 'drain', labels: ['foo=bar']}.to_json, request_headers
      expect(response.status).to eq(200), response.body
      expect(node.reload.labels).to eq(['foo=bar'])
      expect(node.reload.availability).to eq('drain')
    end

    it 'returns error with invalid id' do
      put "/v1/nodes/#{grid.name}/abc", {labels: []}.to_json, request_headers
      expect(response.status).to eq(404)
    end

    it 'returns error with invalid token' do
      node = grid.create_node!('abc', node_id: 'a:b:c')
      put "/v1/nodes/#{node.to_path}", {labels: []}.to_json, {}
      expect(response.status).to eq(403)
    end

    it 'returns 422 if mutation fails' do
      node = grid.create_node!('abc', node_id: 'a:b:c')
      expect(HostNodes::Update).to receive(:run).and_return(double({:success? => false, :errors => double({:message => 'boom'})}))
      put "/v1/nodes/#{node.to_path}", {}, request_headers
      expect(response.status).to eq(422)
    end
  end

  describe 'PUT (legacy)' do
    let(:node) { grid.create_node!('node', node_id: 'abc') }

    it 'saves node labels' do
      node
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
      node
      put '/v1/nodes/abc', {labels: []}.to_json, {}
      expect(response.status).to eq(404)
    end
  end
end
