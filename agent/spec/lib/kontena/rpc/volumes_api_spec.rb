
describe Kontena::Rpc::VolumesApi do
  let(:executor) do
    double(:executor)
  end

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#notify_update' do
    it 'publishes volume update notification' do
      expect(Celluloid::Notifications).to receive(:publish).with('volume:update', 'foo')
      subject.notify_update('foo')
    end
  end
end
