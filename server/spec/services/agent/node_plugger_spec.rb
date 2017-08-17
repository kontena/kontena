describe Agent::NodePlugger do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:subject) { described_class.new(node) }
  let(:rpc_client) { instance_double(RpcClient) }
  let(:connected_at) { Time.now }

  before do
    allow(subject).to receive(:rpc_client).and_return(rpc_client)
  end

  context 'for a brand new node' do
    let(:node) {
      grid.create_node!('test-node', node_id: 'xyz')
    }

    it 'marks node as connected' do
      expect(subject).to receive(:send_master_info)
      expect(subject).to receive(:send_node_info)
      expect {
        subject.plugin! connected_at
      }.to change{ node.reload.connected? }.to be_truthy
    end
  end

  context 'for an existing node' do
    let(:node) {
      grid.create_node!('test-node',
        node_id: 'xyz',
        labels: ['region=ams2'],
        connected: false,
        private_ip: '10.12.1.2', public_ip: '80.240.128.3',
      )
    }

    describe '#plugin!' do
      it 'marks node as connected' do
        expect(subject).to receive(:publish_update_event)
        expect(subject).to receive(:send_master_info)
        expect(subject).to receive(:send_node_info)
        expect {
          subject.plugin! connected_at
        }.to change{ node.reload.connected? }.to be_truthy
      end
    end

    describe '#send_master_info' do
      it "sends version" do
        expect(rpc_client).to receive(:notify).with('/agent/master_info', hash_including(version: String))
        subject.send_master_info
      end
    end

    describe '#send_node_info' do
      it "sends node info" do
        expect(rpc_client).to receive(:notify).with('/agent/node_info', hash_including(
          name: 'test-node',
          grid: hash_including(
            name: 'test-grid',
          ),
        ))

        subject.send_node_info
      end
    end
  end

  context 'for a reconnected node' do
    let(:reconnected_at) { 2.seconds.ago }
    let(:connected_at) { 10.seconds.ago }
    let(:node) {
      grid.create_node!('test-node',
        node_id: 'xyz',
        labels: ['region=ams2'],
        connected: true, connected_at: reconnected_at,
        private_ip: '10.12.1.2', public_ip: '80.240.128.3',
      )
    }

    describe '#plugin!' do
      it 'does not update node' do
        expect(subject).to_not receive(:publish_update_event)
        expect(subject).to_not receive(:send_master_info)
        expect(subject).to_not receive(:send_node_info)

        expect {
          subject.plugin! connected_at
        }.to_not change{ node.reload.connected_at }
      end
    end
  end
end
