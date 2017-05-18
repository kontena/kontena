
describe Scheduler::Strategy::Daemon do

  let(:grid) { Grid.create(name: 'test') }

  let(:host_nodes) do
    [
      HostNode.create!(
      node_id: 'node1', name: 'node-1', connected: true, grid: grid, node_number: 1
      ),
      HostNode.create!(
        node_id: 'node2', name: 'node-2', connected: true, grid: grid, node_number: 2
      ),
      HostNode.create!(
        node_id: 'node3', name: 'node-3', connected: true, grid: grid, node_number: 3
      ),
    ]
  end
  let(:scheduler_nodes) do
    host_nodes.map{|n| Scheduler::Node.new(n)}
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
      expect(subject.sort_candidates(scheduler_nodes.shuffle, stateless_service, 1)).to eq(scheduler_nodes)
    end
  end
end
