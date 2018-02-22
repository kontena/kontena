describe Kontena::Rpc::ServicePodsApi, :celluloid => true do
  describe '#restart' do
    it 'calls service pod restarter' do
      expect(Celluloid::Notifications).to receive(:publish).with('service_pod:restart', {service_id: 'service_id', instance_number: 2})

      subject.restart('service_id', 2)
    end
  end

  describe '#notify_update' do
    it 'notifies service_pod:update' do
      expect(Celluloid::Notifications).to receive(:publish).with('service_pod:update', 'stopped')
      subject.notify_update('stopped')
    end
  end
end
