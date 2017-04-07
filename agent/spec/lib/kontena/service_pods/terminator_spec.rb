
describe Kontena::ServicePods::Terminator do

  let(:service_id) { 'service-id' }
  let(:subject) { described_class.new(service_id, 1) }

  describe '#perform' do
    it 'terminates service instance' do
      service_container = double(:service, :load_balanced? => false, :name => 'foo.bar-1', :name_for_humans => 'foo/bar-1')
      allow(subject).to receive(:get_container).with(service_id, 1).and_return(service_container)
      allow(subject).to receive(:get_container).with(service_id, 1, 'volume')

      expect(service_container).to receive(:stop).with({'timeout' => 10})
      expect(service_container).to receive(:wait)
      expect(service_container).to receive(:delete).with({v: true})
      subject.perform
    end

    it 'removes volumes if exist' do
      service_container = spy(:service, :name_for_humans => 'foo/bar-1')
      service_container_volumes = double(:service, name: '/foo-1-volumes')
      allow(subject).to receive(:get_container).with(service_id, 1).and_return(service_container)
      allow(subject).to receive(:get_container).with(service_id, 1, 'volume').and_return(service_container_volumes)
      expect(service_container_volumes).to receive(:delete).with({v: true})
      subject.perform
    end

    it 'removes volumes if exist and service_container does not exist' do
      service_container_volumes = double(:service, name: '/foo-volumes')
      allow(subject).to receive(:get_container).with(service_id, 1).and_return(nil)
      allow(subject).to receive(:get_container).with(service_id, 1, 'volume').and_return(service_container_volumes)
      expect(service_container_volumes).to receive(:delete).with({v: true})
      subject.perform
    end
  end
end
