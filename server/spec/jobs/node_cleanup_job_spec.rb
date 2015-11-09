require_relative '../spec_helper'

describe NodeCleanupJob do
  let(:grid) { Grid.create!(name: 'test', initial_size: 1)}
  before(:each) do
    Celluloid.boot
    HostNode.create!(
      grid: grid,
      name: "node-1",
      node_number: 1,
      connected: true,
      last_seen_at: 2.hours.ago
    )
    HostNode.create!(
      grid: grid,
      name: "node-2",
      node_number: 2,
      connected: false,
      last_seen_at: 2.hours.ago
    )
    HostNode.create!(
      grid: grid,
      name: "node-3",
      node_number: 3,
      connected: true,
      last_seen_at: 10.minutes.ago
    )
  end
  after(:each) { Celluloid.shutdown }

  describe '#cleanup_stale_nodes' do
    it 'removes old nodes' do
      expect {
        subject.cleanup_stale_nodes
      }.to change{ HostNode.count }.by(-1)
    end

    it 'does not remove old node if its part of initial grid' do
      expect {
        grid.set(initial_size: 3)
        subject.cleanup_stale_nodes
      }.to change{ HostNode.count }.by(0)
    end
  end
end
