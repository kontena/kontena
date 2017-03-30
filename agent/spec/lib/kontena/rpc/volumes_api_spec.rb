
describe Kontena::Rpc::VolumesApi, :celluloid => true do

  describe '#notify_update' do
    it 'publishes volume update notification' do
      expect(Celluloid::Notifications).to receive(:publish).with('volume:update', 'foo')
      subject.notify_update('foo')
    end
  end
end
