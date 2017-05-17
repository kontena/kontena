
describe Scheduler::Filter::VolumePlugin do

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

  let(:local_volume) do
    grid.volumes.create!(name: 'local', driver: 'local', scope: 'instance')
  end

  let(:foo_volume) do
    grid.volumes.create!(name: 'foo', driver: 'foo', scope: 'instance')
  end

  let(:bar_volume) do
    grid.volumes.create!(name: 'bar', driver: 'bar', scope: 'instance')
  end

  let(:service) do
    grid.grid_services.create!(name: 'redis', image_name: 'redis', volumes: ['foo:/data'])
  end

  let(:service_no_vols) do
    grid.grid_services.create!(name: 'nginx', image_name: 'nginx')
  end

  describe '#for_service' do
    context 'with no volumes' do
      it 'returns all nodes if service does not have any volumes' do
        filtered = subject.for_service(service_no_vols, 1, nodes)
        expect(filtered).to eq(nodes)
      end
    end

    it 'returns all nodes with needed single driver' do
      service.service_volumes << ServiceVolume.new(volume: local_volume, path: '/data')
      service.service_volumes << ServiceVolume.new(bind_mount: '/var/lib', path: '/data')
      expect(subject.for_service(service, 1, nodes).map{|n| n.name}).to eq(['node-1', 'node-3'])
    end

    it 'returns all nodes with needed single driver' do
      service.service_volumes << ServiceVolume.new(volume: local_volume, path: '/data')
      service.service_volumes << ServiceVolume.new(volume: foo_volume, path: '/data')
      expect(subject.for_service(service, 1, nodes).map{|n| n.name}).to eq(['node-1'])
    end

    it 'raises if no nodes with all needed drivers' do
      service.service_volumes << ServiceVolume.new(volume: local_volume, path: '/data')
      service.service_volumes << ServiceVolume.new(volume: foo_volume, path: '/data')
      service.service_volumes << ServiceVolume.new(volume: bar_volume, path: '/data')
      expect{subject.for_service(service, 1, nodes)}.to raise_error(Scheduler::Error)
    end

  end
end
