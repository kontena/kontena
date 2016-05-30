require_relative '../../spec_helper'

describe '/v1/grids' do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }
  let(:grid) { Grid.create!(name: 'test') }
  let(:request_headers) do
    {
        'HTTP_KONTENA_GRID_TOKEN' => "#{grid.token}"
    }
  end

  describe 'POST' do
    it 'creates a new node to grid' do
      expect {
        post '/v1/nodes', {id: 'abc', private_ip: '192.168.100.2'}.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ grid.host_nodes.count }.by(1)
      node = HostNode.find_by(node_id: 'abc')
      expect(node).not_to be_nil
      expect(node.node_number).to eq(1)
    end

    it 'does not create a node if it already exists' do
      grid.host_nodes.create!(node_id: 'abc')
      expect {
        post '/v1/nodes', {id: 'abc', private_ip: '192.168.100.2'}.to_json, request_headers
        expect(response.status).to eq(200)
      }.to change{ grid.host_nodes.count }.by(0)
    end

    it 'returns node json' do
      post '/v1/nodes', {id: 'abc', private_ip: '192.168.100.2'}.to_json, request_headers
      expect(json_response['id']).to eq('abc')
      expect(json_response['node_number']).to eq(1)
      expect(json_response['grid']['id']).to eq(grid.to_path)
    end

    it 'returns error if id is null' do
      post '/v1/nodes', {id: nil, private_ip: '192.168.100.2'}.to_json, request_headers
      expect(response.status).to eq(422)
    end

    it 'returns error if grid does not exist' do
      post '/v1/nodes', {id: 'abc', private_ip: '192.168.100.2'}.to_json, {}
      expect(response.status).to eq(404)
    end
  end

  describe 'GET' do
    it 'returns node with valid id and token' do
      grid.host_nodes.create!(node_id: 'abc')
      get '/v1/nodes/abc', nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['id']).to eq('abc')
    end

    it 'returns error with invalid id' do
      get '/v1/nodes/foo', nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'returns error with invalid token' do
      grid.host_nodes.create!(node_id: 'abc')
      get '/v1/nodes/abc', nil, {}
      expect(response.status).to eq(404)
    end
  end

  describe 'PUT' do
    it 'saves node labels' do
      node = grid.host_nodes.create!(node_id: 'abc')
      labels = ['foo=1', 'bar=2']
      put '/v1/nodes/abc', {labels: labels}.to_json, request_headers
      expect(response.status).to eq(200)
      expect(node.reload.labels).to eq(labels)
    end

    it 'returns error with invalid id' do
      put '/v1/nodes/abc', {labels: []}.to_json, request_headers
      expect(response.status).to eq(404)
    end

    it 'returns error with invalid token' do
      grid.host_nodes.create!(node_id: 'abc')
      put '/v1/nodes/abc', {labels: []}.to_json, {}
      expect(response.status).to eq(404)
    end
  end
end
