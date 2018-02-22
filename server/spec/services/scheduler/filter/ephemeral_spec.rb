
describe Scheduler::Filter::Ephemeral do

  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) { [
    grid.create_node!('node-1', node_id: 'node1'),
    grid.create_node!('node-2', node_id: 'node2'),
    grid.create_node!('node-3', node_id: 'node3'),
  ] }

  let(:stateless_service) do
    grid.grid_services.create!(name: 'nginx', image_name: 'nginx')
  end

  let(:stateful_service) do
    grid.grid_services.create!(name: 'redis', image_name: 'redis', stateful: true)
  end

  describe '#for_service' do
    context 'stateles service' do
      it 'returns all nodes for stateless service' do
        filtered = subject.for_service(stateless_service, 1, nodes)
        expect(filtered).to eq(nodes)
      end
    end

    context 'stateful service' do
      it 'returns all nodes when none ephemeral' do
        filtered = subject.for_service(stateful_service, 1, nodes)
        expect(filtered).to eq(nodes)
      end

      it 'returns only non-ephemeral nodes' do
        nodes[0].labels = ['ephemeral=true']
        filtered = subject.for_service(stateful_service, 1, nodes)
        expect(filtered).to eq(nodes[1..2])
      end

      it 'returns also ephemeral if theres existing instance on it' do
        nodes[0].labels = ['ephemeral=true']
        nodes[0].grid_service_instances.create!(grid_service: stateful_service, instance_number: 1)
        nodes[2].labels = ['ephemeral=true']
        filtered = subject.for_service(stateful_service, 1, nodes)
        expect(filtered).to eq(nodes[0..1])
      end

    end
  end

end
