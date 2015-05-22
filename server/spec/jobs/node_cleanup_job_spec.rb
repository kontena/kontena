require_relative '../spec_helper'

describe NodeCleanupJob do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#perform' do
    it 'removes old nodes' do
      HostNode.create!(name: "node-1", connected: false, updated_at: 2.hours.ago)
      HostNode.create!(name: "node-2", connected: true, updated_at: 2.hours.ago)
      HostNode.create!(name: "node-3", connected: true, updated_at: 10.minutes.ago)

      expect {
        subject.perform
      }.to change{ HostNode.count }.by(-1)
    end
  end
end
