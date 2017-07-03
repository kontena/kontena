
describe Scheduler::Filter::Ephemeral do

  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(
      grid: grid, node_id: 'node1', name: 'node-1',
      volume_drivers: [{'name' => 'local'}, {'name' => 'foo'}]
    )
    nodes << HostNode.create!(
      grid: grid, node_id: 'node2', name: 'node-2',
      volume_drivers: [{'name' => 'foo'}]
    )
    nodes << HostNode.create!(
      grid: grid, node_id: 'node3', name: 'node-3',
      volume_drivers: [{'name' => 'local'}, {'name' => 'bar'}]
    )
    nodes
  end

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
    end
  end

end
