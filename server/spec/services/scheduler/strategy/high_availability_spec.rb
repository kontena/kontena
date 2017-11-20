
describe Scheduler::Strategy::HighAvailability do

  let(:grid) { Grid.create(name: 'test') }

  let(:availability_zones) { %w(a b c) }
  let(:nodes) do
    nodes = []
    availability_zones.each do |az|
      2.times do |i|
        instance = i + 1
        nodes << grid.create_node!("node-#{instance}#{az}",
          node_id: "node#{instance}#{az}",
          connected: true,
          labels: ['region=eu-west-1', "az=#{az}"]
        )
      end
    end
    nodes.map { |n| Scheduler::Node.new(n) }
  end

  let(:stateful_service) do
    GridService.create!(name: 'test', grid: grid, image_name: 'foo/bar:latest', stateful: true)
  end

  let(:stateless_service) do
    GridService.create!(name: 'test', grid: grid, image_name: 'foo/bar:latest', stateful: false)
  end

  describe '#find_node' do
    context 'stateful service' do

      it 'returns previously scheduled node if it exists in nodes array' do
        stateful_service.grid_service_instances.create!(instance_number: 2, host_node: nodes[2].node)
        node = subject.find_node(stateful_service, 2, nodes)
        expect(node).to eq(nodes[2])
      end

      it 'returns nil if previously scheduled node does not exist in nodes array' do
        stateful_service.grid_service_instances.create!(instance_number: 2, host_node: nodes[2].node)
        nodes.delete(nodes[2])
        node = subject.find_node(stateful_service, 2, nodes)
        expect(node).to be_nil
      end

      it 'returns a node if previously scheduled node has been removed' do
        stateful_service.grid_service_instances.create!(instance_number: 2, host_node: nodes[2].node)
        nodes.delete(nodes[2]).destroy
        node = subject.find_node(stateful_service, 2, nodes)
        expect(nodes.include?(node)).to be_truthy
      end

      it 'returns node from az that does not yet have service instance' do
        nodes[2].schedule_counter = 1 # az=b
        expect(['a', 'c']).to include(subject.find_node(stateful_service, 2, nodes).availability_zone)
        nodes[1].schedule_counter = 1 # az=a
        expect(['c']).to include(subject.find_node(stateful_service, 3, nodes).availability_zone)
      end

      it 'returns node that has data volume container' do
        stateful_service.grid_service_instances.create!(
          instance_number: 3, host_node: nodes[2].node
        )
        expect(subject.find_node(stateful_service, 3, nodes)).to eq(nodes[2])
      end

      it 'return nil if data volume node is not available' do
        node4 = grid.create_node!('node-4', node_id: 'node4', connected: true)
        stateful_service.grid_service_instances.create!(
          instance_number: 3, host_node: node4
        )
        expect(subject.find_node(stateful_service, 3, nodes)).to be_nil
      end
    end

    context 'stateless service' do

      it 'returns previously scheduled node if it exists in nodes array' do
        stateless_service.grid_service_instances.create!(instance_number: 2, host_node: nodes[2].node)
        node = subject.find_node(stateless_service, 2, nodes)
        expect(node).to eq(nodes[2])
      end

      it 'returns a node if previously scheduled node does not exist in nodes array' do
        stateless_service.grid_service_instances.create!(instance_number: 2, host_node: nodes[2].node)
        nodes.delete(nodes[2])
        node = subject.find_node(stateless_service, 2, nodes)
        expect(nodes.include?(node)).to be_truthy
      end

      it 'returns a node if previously scheduled node has been removed' do
        stateless_service.grid_service_instances.create!(instance_number: 2, host_node: nodes[2].node)
        nodes.delete(nodes[2]).destroy
        node = subject.find_node(stateless_service, 2, nodes)
        expect(nodes.include?(node)).to be_truthy
      end

      it 'returns node from az that does not yet have service instance' do
        nodes[2].schedule_counter = 1 # az=b
        expect(['a', 'c']).to include(subject.find_node(stateless_service, 2, nodes).availability_zone)
        nodes[1].schedule_counter = 1 # az=a
        expect(['c']).to include(subject.find_node(stateless_service, 3, nodes).availability_zone)
      end
    end
  end

  describe '#instance_rank' do
    let(:node) { nodes[0] }

    it 'returns zero rank if instance is not already scheduled to node' do
      stateless_service.grid_service_instances.create!(
        instance_number: 2, host_node: nodes[2].node
      )
      expect(subject.instance_rank(node, stateless_service, 1)).to eq(0.0)
    end

    it 'returns negative rank if instance is already scheduled to node' do
      stateless_service.grid_service_instances.create!(
        instance_number: 2, host_node: node.node
      )
      expect(subject.instance_rank(node, stateless_service, 2) < 0.0).to be_truthy
    end
  end

  describe '#memory_rank' do
    let(:node) { nodes[0] }

    it 'returns 0.0 if node has no memory stats' do
      expect(subject.memory_rank(node)).to eq(0.0)
    end

    it 'returns rank based on memory usage' do
      node.latest_stats = {
        'memory' => { 'used' => 256.megabytes }
      }
      node.mem_total = 1.gigabytes
      expect(subject.memory_rank(node)).to eq(0.25)
    end
  end

  describe '#availability_zone_count' do
    it 'returns schedule count for az' do
      node1 = nodes[0]
      node2 = nodes[1]
      node3 = nodes[2]
      node1.schedule_counter = 2
      node2.schedule_counter = 2
      node3.set(labels: ['region=eu-west-1', 'az=b'])
      expect(subject.availability_zone_count(node1, nodes)).to eq(4)
      expect(subject.availability_zone_count(node3, nodes)).to eq(0)
    end
  end
end
