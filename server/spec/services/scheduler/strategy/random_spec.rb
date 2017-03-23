
describe Scheduler::Strategy::HighAvailability do

  let(:grid) { Grid.create(name: 'test') }

  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(node_id: 'node1', name: 'node-1', connected: true, grid: grid)
    nodes << HostNode.create!(node_id: 'node2', name: 'node-2', connected: true, grid: grid)
    nodes << HostNode.create!(node_id: 'node3', name: 'node-3', connected: true, grid: grid)
    nodes
  end

  let(:stateful_service) do
    GridService.create!(name: 'test', grid: grid, image_name: 'foo/bar:latest', stateful: true)
  end

  let(:stateless_service) do
    GridService.create!(name: 'test', grid: grid, image_name: 'foo/bar:latest', stateful: false)
  end

  describe '#find_node' do
    it 'returns random node' do
      node = subject.find_node(stateless_service, 2, nodes)
      expect(nodes.include?(node)).to be_truthy
    end
  end
end
