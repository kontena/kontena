require_relative '../../spec_helper'

describe '/v1/grids' do

  let(:grid) { Grid.create!(name: 'test') }
  let(:request_headers) do
    {
        'HTTP_KONTENA_GRID_TOKEN' => "#{grid.token}"
    }
  end

  describe 'POST' do
    it 'creates a new node to grid' do
      expect {
        post '/v1/nodes', {node_id: 'abc'}.to_json, request_headers
        expect(response.status).to eq(201)
      }.to change{ grid.host_nodes.count }.by(1)
      node = HostNode.find_by(node_id: 'abc')
      expect(node).not_to be_nil
      expect(node.node_number).to eq(1)
    end

    it 'does not create a node if it already exists' do
      grid.host_nodes.create!(node_id: 'abc')
      expect {
        post '/v1/nodes', {node_id: 'abc'}.to_json, request_headers
        expect(response.status).to eq(200)
      }.to change{ grid.host_nodes.count }.by(0)
    end

    it 'returns node json' do
      post '/v1/nodes', {node_id: 'abc'}.to_json, request_headers
      expect(json_response['id']).to eq('abc')
      expect(json_response['node_number']).to eq(1)
      expect(json_response['grid']['id']).to eq(grid.id.to_s)
    end
  end
end
