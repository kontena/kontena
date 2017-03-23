
describe LeaderElectorJob, celluloid: true do
  before(:each) { DistributedLock.delete_all }

  describe '#elect' do
    it 'elects only one candidate' do
      candidate1 = LeaderElectorJob.new
      candidate2 = LeaderElectorJob.new
      WaitHelper.wait_until!(timeout: 5) { candidate1.leader? || candidate2.leader? }
      expect(candidate1.leader? != candidate2.leader?).to be_truthy
    end
  end
end
