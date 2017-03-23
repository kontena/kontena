
describe Scheduler::Strategy::Daemon do

  let(:grid) { Grid.create(name: 'test') }

  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(
      node_id: 'node2', name: 'node-2', connected: true, grid: grid, node_number: 2
    )
    nodes << HostNode.create!(
      node_id: 'node1', name: 'node-1', connected: true, grid: grid, node_number: 1
    )
    nodes << HostNode.create!(
      node_id: 'node3', name: 'node-3', connected: true, grid: grid, node_number: 3
    )
    nodes
  end

  let(:stateless_service) do
    GridService.create!(name: 'test', grid: grid, image_name: 'foo/bar:latest', stateful: false)
  end

  describe '#instance_count' do
    it 'returns node count multiplied with instance count' do
      expect(subject.instance_count(3, 2)).to eq(6)
    end
  end

  describe '#sort_candidates' do
    it 'sorts by node_number by default' do
      expected_nodes = [nodes[1], nodes[0], nodes[2]]
      expect(subject.sort_candidates(nodes, stateless_service, 1)).to eq(expected_nodes)
    end
  end
end
