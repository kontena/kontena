describe Agent::NodePlugger do
  let(:grid) { Grid.create! name: 'test-grid' }
  let(:node) {
    HostNode.create!(
      node_id: 'xyz',
      grid: grid, name: 'test-node', labels: ['region=ams2'],
      private_ip: '10.12.1.2', public_ip: '80.240.128.3'
    )
  }
  let(:subject) { described_class.new(grid, node) }
  let(:rpc_client) { instance_double(RpcClient) }

  before do
    allow(subject).to receive(:rpc_client).and_return(rpc_client)
  end

  describe '#plugin!' do
    it 'marks node as connected' do
      expect(subject).to receive(:send_master_info)
      expect(subject).to receive(:send_node_info)
      expect {
        subject.plugin!
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
