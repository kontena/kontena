require_relative '../spec_helper'

describe LeaderElectorJob do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#elect' do
    it 'elects only one candidate' do
      candidate1 = LeaderElectorJob.new
      candidate2 = LeaderElectorJob.new
      sleep 0.1
      expect(candidate1.leader? != candidate2.leader?).to be_truthy
    end
  end
end