
describe GridServiceScheduler do

  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:grid_nodes) do
    (1..3).map { |i|
      HostNode.create!(node_id: SecureRandom.uuid, name: "node-#{i}", node_number: i, mem_total: 1.gigabytes)
    }
  end
  let(:nodes) do
    grid_nodes.map { |n| Scheduler::Node.new(n) }
  end
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(strategy) }

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
