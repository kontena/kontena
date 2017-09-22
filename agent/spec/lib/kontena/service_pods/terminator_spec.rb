
describe Kontena::ServicePods::Terminator do

  let(:service_pod) { double(:service_pod, service_id: 'service_id', instance_number: 1)}
  let(:hook_manager) { double(:hook_manager) }
  let(:subject) { described_class.new(service_pod, hook_manager) }

  describe '#perform' do
    before(:each) do
      allow(hook_manager).to receive(:track)
      allow(hook_manager).to receive(:on_pre_stop)
    end

    it 'terminates service instance' do
      service_container = double(:service,
        :load_balanced? => false, :name => 'foo.bar-1', :name_for_humans => 'foo/bar-1',
        :stop_grace_period => 15, :running? => true
      )
      allow(subject).to receive(:get_container).with('service_id', 1).and_return(service_container)
      allow(subject).to receive(:get_container).with('service_id', 1, 'volume')

      expect(hook_manager).to receive(:on_pre_stop).once
      expect(service_container).to receive(:stop).with({'timeout' => 15})
      expect(service_container).to receive(:wait)
      expect(service_container).to receive(:delete).with({v: true})
      subject.perform
    end

    it 'removes volumes if exist' do
      service_container = spy(:service, :name_for_humans => 'foo/bar-1')
      service_container_volumes = double(:service, name: '/foo-1-volumes')
      allow(subject).to receive(:get_container).with('service_id', 1).and_return(service_container)
      allow(subject).to receive(:get_container).with('service_id', 1, 'volume').and_return(service_container_volumes)
      expect(service_container_volumes).to receive(:delete).with({v: true})
      subject.perform
    end

    it 'removes volumes if exist and service_container does not exist' do
      service_container_volumes = double(:service, name: '/foo-volumes')
      allow(subject).to receive(:get_container).with('service_id', 1).and_return(nil)
      allow(subject).to receive(:get_container).with('service_id', 1, 'volume').and_return(service_container_volumes)
      expect(service_container_volumes).to receive(:delete).with({v: true})
      subject.perform
    end
  end
end
