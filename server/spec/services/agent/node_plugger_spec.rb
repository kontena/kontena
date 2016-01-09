require_relative '../../spec_helper'

describe Agent::NodePlugger do

  let(:grid) { Grid.create! }
  let(:node) { HostNode.create!(grid: grid, name: 'test-node') }
  let(:subject) { described_class.new(grid, node) }
  let(:client) { spy(:client) }

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
end
