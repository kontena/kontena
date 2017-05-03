
describe GridServiceScheduler do

  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:nodes) do
    nodes = []
    3.times { nodes << HostNode.create!(node_id: SecureRandom.uuid) }
    nodes.map { |n| Scheduler::Node.new(n) }
  end
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(strategy) }

  describe '#selected_nodes' do
    before(:each) do
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
    end

    it 'returns instance_count amount of nodes by default' do
      expect(subject.selected_nodes(grid_service, grid.host_nodes.to_a).size).to eq(1)
    end

    it 'returns filtered amount of unique nodes if service has affinity' do
      service = GridService.create!(
        image_name: 'kontena/redis:2.8', name: 'redis', grid: grid,
        container_count: 3, affinity: ['label==foo']
      )
      expect(subject.selected_nodes(service, grid.host_nodes.to_a).size).to eq(3)
      expect(subject.selected_nodes(service, grid.host_nodes.to_a).uniq.size).to eq(2)
    end
  end

  describe '#calculated_instance_count' do

    let(:scheduler_nodes) { grid.host_nodes.map{ |n| Scheduler::Node.new(n) } }

    it 'returns grid_service#container_count by default' do
      expect(subject.calculated_instance_count(grid_service, scheduler_nodes)).to eq(grid_service.container_count)
    end

    it 'returns count based on filtered nodes if strategy is daemon' do
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['bar'])
      service = GridService.create!(
        image_name: 'kontena/redis:2.8', name: 'redis', grid: grid,
        container_count: 3, affinity: ['label==foo']
      )
      subject = described_class.new(Scheduler::Strategy::Daemon.new)
      expect(subject.calculated_instance_count(service, scheduler_nodes)).to eq(6)
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
      subject = described_class.new(Scheduler::Strategy::Daemon.new)
      expect(subject.calculated_instance_count(service, scheduler_nodes)).to eq(2)
    end
  end

  describe '#select_node' do
    it 'filters nodes' do
      expect(subject).to receive(:filter_nodes).once.with(grid_service, 'foo-1', nodes).and_return(nodes)
      subject.select_node(grid_service, 'foo-1', nodes)
    end

    it 'returns a node' do
      node = subject.select_node(grid_service, 'foo-1', nodes)
      expect(nodes.include?(node)).to eq(true)
    end

    it 'fails if all nodes are offline' do
      expect{subject.select_node(grid_service, 1, [])}.to raise_error(Scheduler::Error, "There are no nodes available")
    end
  end

  describe '#filter_nodes' do
    it 'filters every node' do
      subject.filters.each do |filter|
        expect(filter).to receive(:for_service).once.with(grid_service, 'foo-1', anything).and_call_original
      end
      subject.filter_nodes(grid_service, 'foo-1', nodes)
    end
  end
end
