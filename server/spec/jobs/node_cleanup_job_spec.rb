require_relative '../spec_helper'

describe NodeCleanupJob do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:grid) { Grid.create!(name: 'test') }

  describe '#cleanup_stale_nodes' do
    it 'removes old nodes' do
      HostNode.create!(name: "node-1", grid: grid, connected: true, last_seen_at: 2.hours.ago)
      HostNode.create!(name: "node-2", grid: grid, connected: false, last_seen_at: 2.hours.ago)
      HostNode.create!(name: "node-3", grid: grid, connected: true, last_seen_at: 10.minutes.ago)

      expect {
        subject.cleanup_stale_nodes
      }.to change{ HostNode.count }.by(-1)
    end

    it 'does not remove initial node' do
      HostNode.create!(name: "node-1", grid: grid, connected: false, last_seen_at: 2.hours.ago)
      HostNode.create!(name: "node-2", grid: grid, connected: true, last_seen_at: 2.hours.ago)
      HostNode.create!(name: "node-3", grid: grid, connected: true, last_seen_at: 10.minutes.ago)

      expect {
        subject.cleanup_stale_nodes
      }.not_to change{ HostNode.count }
    end

    it 'does not remove node with stateful services' do
      HostNode.create!(name: "node-1", grid: grid, connected: false, last_seen_at: 2.hours.ago)
      node2 = HostNode.create!(name: "node-2", grid: grid, connected: false, last_seen_at: 2.hours.ago)
      HostNode.create!(name: "node-3", grid: grid, connected: true, last_seen_at: 10.minutes.ago)
      service = GridService.create!(name: 'test', image_name: 'foo/bar:latest', grid: grid, stateful: true)
      service.containers.create!(name: 'test-1', host_node: node2)
      expect {
        subject.cleanup_stale_nodes
      }.not_to change{ HostNode.count }
    end
  end
end
