describe Scheduler::Strategy::Random do

  let(:grid) { Grid.create(name: 'test') }

  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(node_id: 'node1', name: 'node-1', connected: true, grid: grid)
    nodes << HostNode.create!(node_id: 'node2', name: 'node-2', connected: true, grid: grid)
    nodes << HostNode.create!(node_id: 'node3', name: 'node-3', connected: true, grid: grid)
    nodes.map { |n| Scheduler::Node.new(n) }
  end

  let(:stateful_service) do
    GridService.create!(
      strategy: 'random', name: 'test', grid: grid, image_name: 'foo/bar:latest', stateful: true
    )
  end

  let(:stateless_service) do
    GridService.create!(
      strategy: 'random', name: 'test', grid: grid, image_name: 'foo/bar:latest', stateful: false
    )
  end

  describe '#find_node' do
    context 'stateless' do 
      it 'returns a node if no previous instance exist' do
        node = subject.find_node(stateless_service, 2, nodes)
        expect(nodes.include?(node)).to be_truthy
      end

      it 'returns previously scheduled node if it exists' do
        stateless_service.grid_service_instances.create!(instance_number: 2, host_node: nodes[2].node)
        node = subject.find_node(stateless_service, 2, nodes)
        expect(node).to eq(nodes[2])
      end

      it 'returns a node if previously scheduled node is not included in nodes array' do
        stateless_service.grid_service_instances.create!(instance_number: 2, host_node: nodes[2].node)
        nodes.delete(nodes[2])
        node = subject.find_node(stateless_service, 2, nodes)
        expect(node).not_to eq(nodes[2])
      end
    end

    context 'stateful' do
      it 'returns a node if no previous instance exist' do
        node = subject.find_node(stateful_service, 2, nodes)
        expect(nodes.include?(node)).to be_truthy
      end

      it 'returns previously scheduled node if it exists' do
        stateful_service.grid_service_instances.create!(instance_number: 2, host_node: nodes[2].node)
        node = subject.find_node(stateful_service, 2, nodes)
        expect(node).to eq(nodes[2])
      end

      it 'returns nil if previously scheduled node is not included in nodes array' do
        stateful_service.grid_service_instances.create!(instance_number: 2, host_node: nodes[2].node)
        nodes.delete(nodes[2])
        node = subject.find_node(stateful_service, 2, nodes)
        expect(node).to be_nil
      end
    end
  end
end
