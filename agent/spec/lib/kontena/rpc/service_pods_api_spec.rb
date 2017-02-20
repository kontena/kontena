
describe Kontena::Rpc::ServicePodsApi do
  let(:executor) do
    double(:executor)
  end

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#restart' do
    it 'calls service pod restarter' do
      expect(Kontena::ServicePods::Restarter).to receive(:new).and_return(executor)
      expect(executor).to receive(:perform)
      subject.restart('service_id', 2)
    end
  end

  describe '#notify_update' do
    it 'calls service pod restarter' do
      expect(Celluloid::Notifications).to receive(:publish).with('service_pod:update', 'stopped')
      subject.notify_update('stopped')
    end
  end
end
