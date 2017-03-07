
describe HostNodes::Remove, celluloid: true do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node_a) { HostNode.create!(name: 'node-a', grid: grid, node_id: 'AA') }
  let(:node_b) { HostNode.create!(name: 'node-b', grid: grid, node_id: 'BB') }

  describe '#run' do
    let(:subject) { described_class.new(host_node: node_a) }
    before(:each) { allow(subject).to receive(:worker).and_return(spy(:worker)) }

    it 'removes node' do
      node_a; node_b
      expect {
        subject.run
      }.to change{ grid.host_nodes.count }.by(-1)
    end

    it 'triggers grid_scheduler worker' do
      expect(subject).to receive(:worker).once.with(:grid_scheduler)
      subject.run
    end

    it 'notifies grid nodes' do
      expect(subject).to receive(:notify_grid).once.with(grid)
      subject.run
    end
  end
end
