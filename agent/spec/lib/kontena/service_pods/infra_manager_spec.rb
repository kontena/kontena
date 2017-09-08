describe Kontena::ServicePods::InfraManager do
  let(:network_manager) { double(:network_manager) }
  let(:service_pod) { double(:service_pod, service_id: 'foo', instance_number: '1') }
  let(:subject) { described_class.new(service_pod) }

  before(:each) do
    allow(subject).to receive(:network_manager).and_return(network_manager)
  end

  describe '#ensure_infra' do
    it 'creates infra container if not exists' do
      allow(subject).to receive(:get_container).and_return(nil)
      container = double(:container, :running? => true)
      expect(subject).to receive(:create_infra).and_return(container)
      subject.ensure_infra(nil)
    end

    it 'removes service container if infra container does not exist' do
      allow(subject).to receive(:get_container).and_return(nil)
      container = double(:container, :running? => true)
      allow(subject).to receive(:create_infra).and_return(container)

      service_container = double(:service_container)
      expect(subject).to receive(:remove_container).with(service_container)
      subject.ensure_infra(service_container)
    end

    it 'starts infra if not running' do
      allow(subject).to receive(:get_container).and_return(nil)
      container = double(:container, :running? => false)
      allow(subject).to receive(:create_infra).and_return(container)

      expect(subject).to receive(:start_infra).with(container)
      subject.ensure_infra(nil)
    end
  end

  describe '#terminate' do
    it 'removes infra container' do
      container = double(:container, overlay_network: 'kontena', overlay_cidr: '10.81.1.3/16')
      allow(subject).to receive(:get_container).and_return(container)
      expect(subject).to receive(:remove_container).with(container)
      expect(subject).to receive(:detach_network).with(container)
      subject.terminate
    end

    it 'does nothing if infra container does not exist' do
      allow(subject).to receive(:get_container).and_return(nil)
      expect(subject).not_to receive(:remove_container)
      subject.terminate
    end
  end
end