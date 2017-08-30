
describe Agent::NodeUnplugger do

  let(:grid) { Grid.create! }
  let(:connected_at) { 1.minute.ago }
  let(:node) { grid.create_node!('test-node', connected: true, connected_at: connected_at) }
  let(:subject) { described_class.new(node) }

  context "For a connected node" do
    before do
      node
    end

    describe '#unplug!' do
      it 'marks node as disconnected' do
        expect(subject).to receive(:update_node_containers)

        expect {
          subject.unplug! connected_at
        }.to change{ node.reload.connected? }.from(true).to(false)
      end
    end
  end

  context "For a node that has reconnected" do
    let(:reconnected_at) { 10.seconds.ago }

    let(:node) { grid.create_node!('test-node', connected: true, connected_at: reconnected_at) }
    let(:subject) { described_class.new(node) }

    before do
      node
    end

    describe '#unplug!' do
      it 'does not mark node as disconnected' do
        expect(subject).to_not receive(:update_node_containers)

        expect {
          subject.unplug! connected_at
        }.to_not change{ node.reload.connected? }.from(true)
      end
    end
  end

  context "For a node with service and volume containers" do
    let(:service_container) { node.containers.create!(name: 'foo-1') }
    let(:volume_container) { node.containers.create!(name: 'foo-1-volumes', container_type: 'volume') }

    before do
      service_container
      volume_container
    end

    describe '#update_node_containers' do
      it 'marks containers as deleted' do
        expect {
          subject.update_node_containers
        }.to change{ node.containers.count }.by(-1)

        expect(service_container.reload.deleted_at).to_not be_nil
        expect(volume_container.reload.deleted_at).to be_nil
      end
    end
  end
end
