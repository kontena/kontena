
describe Scheduler::Filter::VolumeInstance do

  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) { [
    grid.create_node!('node-1', node_id: 'node1'),
    grid.create_node!('node-2', node_id: 'node2'),
    grid.create_node!('node-3', node_id: 'node3'),
  ] }

  let(:volume) do
    grid.volumes.create!(name: 'foo', driver: 'local', scope: 'instance')
  end

  let(:service) do
    svc = grid.grid_services.create!(name: 'redis', image_name: 'redis', volumes: ['foo:/data'])
    svc.service_volumes << ServiceVolume.new(volume: volume, path: '/data')
    svc
  end

  let(:service_no_vols) do
    grid.grid_services.create!(name: 'nginx', image_name: 'nginx')
  end

  describe '#for_service' do
    context 'no volumes' do
      it 'returns all nodes if service does not have any volumes' do
        filtered = subject.for_service(service_no_vols, 1, nodes)
        expect(filtered).to eq(nodes)
      end
    end

    context 'instance scope' do
      it 'returns all nodes when no volume instances found' do
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(3)
      end

      it 'returns only node with a volume instance' do
        nodes[0].volume_instances.create!(name: volume.name_for_service(service, 1), volume: volume)
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(1)
        expect(filtered[0].name).to eq('node-1')
      end
    end

    context 'grid scope' do
      let(:volume) do
        grid.volumes.create!(name: 'foo', driver: 'local', scope: 'grid')
      end

      let(:service) do
        svc = grid.grid_services.create!(name: 'redis', image_name: 'redis', volumes: ['foo:/data'])
        svc.service_volumes << ServiceVolume.new(volume: volume, path: '/data')
        svc
      end

      it 'returns all nodes' do
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(3)
      end
    end

    context 'stack scope' do
      let(:volume) do
        grid.volumes.create!(name: 'foo', driver: 'local', scope: 'stack')
      end

      let(:service) do
        svc = grid.grid_services.create!(name: 'redis', image_name: 'redis', volumes: ['foo:/data'])
        svc.service_volumes << ServiceVolume.new(volume: volume, path: '/data')
        svc
      end

      it 'returns all nodes' do
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(3)
      end
    end

  end
end
