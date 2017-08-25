describe HostNodes::Common do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node_a) { grid.create_node!('node-a', node_id: 'AA', connected: true) }
  let(:node_b) { grid.create_node!('node-b', node_id: 'BB', connected: true) }
  let(:node_c) { grid.create_node!('node-c', node_id: 'CC', connected: false) }
  let(:described_class) {
    Class.new do
      include HostNodes::Common
    end
  }

  describe '#notify_grid' do
    it 'notifies all connected nodes' do
      node_a; node_b; node_c
      expect(subject).to receive(:notify_node).once.with(grid, node_a)
      expect(subject).to receive(:notify_node).once.with(grid, node_b)
      expect(subject).not_to receive(:notify_node).with(grid, node_c)
      subject.notify_grid(grid)
    end
  end
end
