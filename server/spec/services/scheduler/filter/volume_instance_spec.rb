
describe Scheduler::Filter::VolumeInstance do

  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(grid: grid, node_id: 'node1', name: 'node-1', labels: ['az-1', 'ssd'])
    nodes << HostNode.create!(grid: grid, node_id: 'node2', name: 'node-2', labels: ['az-1', 'hdd'])
    nodes << HostNode.create!(grid: grid, node_id: 'node3', name: 'node-3', labels: ['az-2', 'ssd'])
    nodes
  end

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
    it 'returns all nodes if service does not have any volumes' do
      filtered = subject.for_service(service_no_vols, 1, nodes)
      expect(filtered).to eq(nodes)
    end

    it 'returns only node with a volume instance' do
      nodes[0].volume_instances.create!(name: volume.name_for_service(service, 1), volume: volume)
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered.size).to eq(1)
      expect(filtered[0].name).to eq('node-1')
    end
  end
end
