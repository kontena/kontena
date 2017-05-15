
describe Scheduler::Filter::Availability do

  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(grid: grid, node_id: 'node1', name: 'node-1', labels: ['az-1', 'ssd'])
    nodes << HostNode.create!(grid: grid, node_id: 'node2', name: 'node-2', labels: ['az-1', 'hdd'])
    nodes << HostNode.create!(grid: grid, node_id: 'node3', name: 'node-3', labels: ['az-2', 'ssd'])
    nodes
  end
  let(:service) {double(:service)}


  describe '#for_service' do
    it 'returns all nodes if none are on drain mode' do
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered).to eq(nodes)
    end

    it 'returns only unevacuated nodes' do
      nodes[2].availability = 'drain'
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered).not_to include(nodes[2])
    end

  end
end
