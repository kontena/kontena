
describe HostNodes::Remove, celluloid: true do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node_a) { grid.create_node!('node-a', node_id: 'AA') }
  let(:node_b) { grid.create_node!('node-b', node_id: 'BB') }

  describe '#run' do
    let(:subject) { described_class.new(host_node: node_a) }
    before(:each) { allow(subject).to receive(:worker).and_return(spy(:worker)) }

    it 'removes node' do
      node_a; node_b
      expect {
        subject.run
      }.to change{ grid.host_nodes.count }.by(-1)
    end

    it 'notifies grid nodes' do
      expect(subject).to receive(:notify_grid).once.with(grid)
      subject.run
    end
  end
end
