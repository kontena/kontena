
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

    it 'sends node info to agent' do
      allow(subject).to receive(:rpc_client).and_return(client)
      expect(client).to receive(:notify).with('/agent/node_info', anything)
      subject.plugin!
    end

    it 'reschedules grid if node has not seen before' do
      expect(subject).to receive(:worker).with(:grid_scheduler).and_return(spy)
      subject.plugin!
    end

    it 'reschedules grid if node has not seen within 2 minutes' do
      node.set(:last_seen_at => (Time.now.utc - 3.minutes))
      expect(subject).to receive(:worker).with(:grid_scheduler).and_return(spy)
      subject.plugin!
    end

    it 'does not reschedule grid if node has seen within 2 minutes' do
      node.set(:last_seen_at => (Time.now.utc - 1.minute - 59.seconds))
      expect(subject).not_to receive(:worker).with(:grid_scheduler)
      subject.plugin!
    end
  end

  describe '#node_info' do
    it 'returns correct peer ips' do
      HostNode.create!(
        grid: grid, name: 'test-node-2', labels: ['region=ams2'],
        private_ip: '10.12.1.3', public_ip: '80.240.128.4'
      )
      HostNode.create!(
        grid: grid, name: 'test-node-3', labels: ['region=ams3'],
        private_ip: '10.23.1.4', public_ip: '146.185.176.0'
      )
      info = subject.node_info
      expect(info['peer_ips']).to include('10.12.1.3')
      expect(info['peer_ips']).to include('146.185.176.0')
    end
  end
end
