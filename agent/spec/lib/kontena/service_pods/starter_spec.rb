
describe Kontena::ServicePods::Starter do

  let(:service_pod) { double(:service_pod, service_id: 'service_id', instance_number: 1)}
  let(:hook_manager) { double(:hook_manager) }
  let(:subject) { described_class.new(service_pod, hook_manager) }

  describe '#perform' do

    let(:container) do
      double(:container, :running? => false, :name_for_humans => 'foo/bar-1')
    end

    before(:each) do
      allow(hook_manager).to receive(:track)
      allow(subject).to receive(:get_container).and_return(container)
    end

    it 'does nothing if container is running' do
      allow(container).to receive(:running?).and_return(true)
      expect(container).to_not receive(:restart!)
      subject.perform
    end

    it 'starts container if not running' do
      expect(hook_manager).to receive(:on_pre_start).once
      expect(hook_manager).to receive(:on_post_start).once
      expect(container).to receive(:start!)
      subject.perform
    end

    it 'fails if container start fails' do
      expect(hook_manager).to receive(:on_pre_start).once
      expect(container).to receive(:start!).and_raise(Docker::Error::ServerError, "failed")
      expect{subject.perform}.to raise_error(Docker::Error::ServerError)
    end
  end
end
