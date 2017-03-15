require_relative '../spec_helper'

describe LeaderElectorJob do
  before(:each) {
    Celluloid.boot
    DistributedLock.delete_all
  }
  after(:each) { Celluloid.shutdown }

  describe '#elect' do
    it 'elects only one candidate' do
      candidate1 = LeaderElectorJob.new
      candidate2 = LeaderElectorJob.new
      WaitHelper.wait!(timeout: 5) { candidate1.leader? || candidate2.leader? }
      expect(candidate1.leader? != candidate2.leader?).to be_truthy
    end
  end
end
