
describe Agent::NodeUnplugger do

  let(:grid) { Grid.create! }
  let(:node) { HostNode.create!(grid: grid, name: 'test-node', connected: true) }
  let(:subject) { described_class.new(node) }
  let(:client) { spy(:client) }

  describe '#unplug!' do
    it 'marks node as disconnected' do
      expect {
        subject.unplug!
      }.to change{ node.reload.connected? }.to be_falsey
    end

    it 'marks containers as deleted' do
      node.containers.create!(name: 'foo-1')
      volume = node.containers.create!(name: 'foo-1-volumes', container_type: 'volume')
      expect {
        subject.unplug!
      }.to change{ node.containers.count }.by(-1)
      expect(volume.reload.deleted_at).to be_nil
    end
  end
end
