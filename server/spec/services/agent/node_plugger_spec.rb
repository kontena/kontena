
describe Agent::NodePlugger do

  let(:grid) { Grid.create! }
  let(:node) {
    HostNode.create!(
      grid: grid, name: 'test-node', labels: ['region=ams2'],
      private_ip: '10.12.1.2', public_ip: '80.240.128.3'
    )
  }
  let(:subject) { described_class.new(grid, node) }
  let(:client) { spy(:client) }

  before(:each) do
    allow(subject).to receive(:worker).and_return(spy)
  end

  describe '#plugin!' do
    it 'marks node as connected' do
      expect {
        subject.plugin!
      }.to change{ node.reload.connected? }.to be_truthy
    end

    it 'sends master info to agent' do
      allow(subject).to receive(:rpc_client).and_return(client)
      expect(client).to receive(:notify).with('/agent/master_info', anything)
      subject.plugin!
    end
  end
end
