
describe Scheduler::Filter::Port do

  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(node_id: 'node1', name: 'node-1', node_number: 1)
    nodes << HostNode.create!(node_id: 'node2', name: 'node-2', node_number: 2)
    nodes << HostNode.create!(node_id: 'node3', name: 'node-3', node_number: 3)
    nodes
  end

  let(:grid) do
    Grid.create!(name: 'test-grid')
  end

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
      service.containers.create!(
        name: 'redis-1',
        host_node: nodes[1],
        instance_number: 1,
        network_settings: {
          'ports' => {
            '6379/tcp' => [{'node_port' => 6379, 'node_ip' => '0.0.0.0'}]
          }
        }
      )
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered).to eq(nodes)
    end

    it 'returns filtered nodes' do
      service2.containers.create!(
        name: 'redis2-1',
        host_node: nodes[1],
        network_settings: {
          'ports' => {
            '6379/tcp' => [{'node_port' => 6379, 'node_ip' => '0.0.0.0'}]
          }
        }
      )
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered.size).to eq(2)
      expect(filtered[0]).to eq(nodes[0])
      expect(filtered[1]).to eq(nodes[2])
    end

    it 'returns empty array if nodes does not have port free' do
      nodes.each do |node|
        service2.containers.create!(
          name: "redis2-#{node.node_id}",
          host_node: node,
          network_settings: {
            'ports' => {
              '6379/tcp' => [{'node_port' => 6379, 'node_ip' => '0.0.0.0'}]
            }
          }
        )
      end

      expect{subject.for_service(service, 1, nodes)}.to raise_error(Scheduler::Error)
    end
  end
end
