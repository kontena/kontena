
describe Kontena::Rpc::ServicePodsApi do
  let(:executor) do
    double(:executor)
  end

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#restart' do
    it 'calls service pod restarter' do
      service_pod = double(:service_pod)
      allow(subject).to receive(:find_service_pod).and_return(service_pod)
      expect(Kontena::ServicePods::Restarter).to receive(:new).with(service_pod).and_return(executor)
      expect(executor).to receive(:perform)
      subject.restart('service_id', 2)
    end

    it 'raises error if service_pod not found' do
      allow(subject).to receive(:find_service_pod).and_return(nil)
      expect {
        subject.restart('service_id', 2)
      }.to raise_error(Kontena::RpcServer::Error)
    end
  end

  describe '#notify_update' do
    it 'calls service pod restarter' do
      expect(Celluloid::Notifications).to receive(:publish).with('service_pod:update', 'stopped')
      subject.notify_update('stopped')
    end
  end
end
