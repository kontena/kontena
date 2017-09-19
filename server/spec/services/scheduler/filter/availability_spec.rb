
describe Scheduler::Filter::Availability do

  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) { [
    grid.create_node!('node-1', node_id: 'node1', labels: ['az-1', 'ssd']),
    grid.create_node!('node-2', node_id: 'node2', labels: ['az-1', 'hdd']),
    grid.create_node!('node-3', node_id: 'node3', labels: ['az-2', 'ssd']),
  ] }
  let(:service) {double(:service)}


  describe '#for_service' do
    it 'returns all nodes if none are on drain mode' do
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered).to eq(nodes)
    end

    it 'returns only unevacuated nodes' do
      nodes[2].availability = HostNode::Availability::DRAIN
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered).not_to include(nodes[2])
    end

  end
end
