
describe GridServiceDeployer do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:grid_service_deploy) { GridServiceDeploy.create(grid_service: grid_service) }
  let(:node1) { HostNode.create!(node_id: SecureRandom.uuid, grid: grid) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(strategy, grid_service_deploy, grid.host_nodes.to_a) }

  describe '#selected_nodes' do
    before(:each) do
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
    end

    it 'returns instance_count amount of nodes by default' do
      expect(subject.selected_nodes.size).to eq(1)
    end

    it 'returns filtered amount of unique nodes if service has affinity' do
      service = GridService.create!(
        image_name: 'kontena/redis:2.8', name: 'redis', grid: grid,
        container_count: 3, affinity: ['label==foo']
      )
      service_deploy = GridServiceDeploy.create(grid_service: service)
      subject = described_class.new(strategy, service_deploy, grid.host_nodes.to_a)
      expect(subject.selected_nodes.size).to eq(3)
      expect(subject.selected_nodes.uniq.size).to eq(2)
    end
  end

  describe '#instance_count' do
    it 'returns grid_service#container_count by default' do
      expect(subject.instance_count).to eq(grid_service.container_count)
    end

    it 'returns count based on filtered nodes if strategy is daemon' do
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['bar'])
      service = GridService.create!(
        image_name: 'kontena/redis:2.8', name: 'redis', grid: grid,
        container_count: 3, affinity: ['label==foo']
      )
      service_deploy = GridServiceDeploy.create(grid_service: service)
      subject = described_class.new(
        Scheduler::Strategy::Daemon.new, service_deploy, grid.host_nodes.to_a
      )
      expect(subject.instance_count).to eq(6)
    end

    it 'returns count based on filtered nodes if strategy is daemon and stack is non-default' do
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['bar'])
      stack = grid.stacks.create(name: 'redis')
      service = GridService.create!(
        image_name: 'kontena/redis:2.8', name: 'redis', grid: grid, stack: stack,
        container_count: 1, affinity: ['label==foo'], strategy: 'daemon'
      )
      service_deploy = GridServiceDeploy.create(grid_service: service)
      subject = described_class.new(
        Scheduler::Strategy::Daemon.new, service_deploy, grid.host_nodes.to_a
      )
      expect(subject.instance_count).to eq(2)
    end
  end
end
