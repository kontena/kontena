require_relative '../spec_helper'

describe NodeCleanupJob do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#cleanup_stale_nodes' do
    it 'removes old nodes' do
      HostNode.create!(name: "node-1", connected: false, updated_at: 2.hours.ago)
      HostNode.create!(name: "node-2", connected: true, updated_at: 2.hours.ago)
      HostNode.create!(name: "node-3", connected: true, updated_at: 10.minutes.ago)

      expect {
        subject.cleanup_stale_nodes
      }.to change{ HostNode.count }.by(-1)
    end
  end
end
