
describe Scheduler::Filter::Port do
  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) { [
    grid.create_node!('node-1'),
    grid.create_node!('node-2'),
    grid.create_node!('node-3'),
  ] }

  let(:service) do
    GridService.create(
      name: 'redis',
      grid: grid,
      image_name: 'redis:2.8',
      ports: [
        {'node_port' => 6379, 'container_port' => 6379}
      ]
    )
  end

  let(:service2) do
    GridService.create(
      name: 'redis2',
      grid: grid,
      image_name: 'redis:2.8',
      ports: [
        {'node_port' => 6379, 'container_port' => 6379}
      ]
    )
  end

  describe '#for_service' do
    it 'returns all nodes if nodes does not have any conflicting containers' do
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered).to eq(nodes)
    end

    it 'does not filter out same service instance' do
      service.grid_service_instances.create!(
        host_node: nodes[1],
        instance_number: 1
      )
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered).to eq(nodes)
    end

    it 'returns filtered nodes' do
      service2.grid_service_instances.create!(
        host_node: nodes[1],
        instance_number: 1
      )
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered.size).to eq(2)
      expect(filtered[0]).to eq(nodes[0])
      expect(filtered[1]).to eq(nodes[2])
    end

    it 'returns empty array if nodes does not have port free' do
      i = 0
      nodes.each do |node|
        i += 1
        service2.grid_service_instances.create!(
          host_node: node,
          instance_number: i
        )
      end

      expect{subject.for_service(service, 1, nodes)}.to raise_error(Scheduler::Error)
    end
  end
end
