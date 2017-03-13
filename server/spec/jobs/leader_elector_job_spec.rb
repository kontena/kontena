
describe LeaderElectorJob, celluloid: true do
  before(:each) { DistributedLock.delete_all }

  describe '#elect' do
    it 'elects only one candidate' do
      candidate1 = LeaderElectorJob.new
      candidate2 = LeaderElectorJob.new
      Timeout.timeout(5) do
        sleep 0.1 until candidate1.leader? || candidate2.leader?
      end
      expect(candidate1.leader? != candidate2.leader?).to be_truthy
    end
  end
end
