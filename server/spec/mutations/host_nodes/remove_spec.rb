
describe HostNodes::Remove, celluloid: true do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node_a) { HostNode.create!(name: 'node-a', grid: grid, node_id: 'AA', connected: false) }
  let(:node_b) { HostNode.create!(name: 'node-b', grid: grid, node_id: 'BB', connected: true) }

  context "for an offline node" do
    subject { described_class.new(host_node: node_a) }

    before(:each) { allow(subject).to receive(:worker).and_return(spy(:worker)) }

    it 'removes node' do
      node_a; node_b
      expect {
        expect(subject.run).to be_success
      }.to change{ grid.host_nodes.count }.by(-1)
    end

    it 'notifies grid nodes' do
      expect(subject).to receive(:notify_grid).once.with(grid)
      subject.run
    end
  end

  context "for an online node" do
    subject { described_class.new(host_node: node_b) }

    it "does not remove the node" do
      node_a; node_b
      expect {
        expect(subject.run).to_not be_success
      }.to_not change{ grid.host_nodes.count }
    end
  end
end
