
describe Kontena::ServicePods::Stopper do

  let(:service_pod) { double(:service_pod, service_id: 'service_id', instance_number: 1)}
  let(:subject) { described_class.new(service_pod) }

  describe '#perform' do

    let(:container) do
      double(:container, :running? => true, :name_for_humans => 'foo/bar-1', :stop_grace_period => 10)
    end

    before(:each) do
      allow(subject).to receive(:get_container).and_return(container)
    end

    it 'does nothing if container is not running' do
      allow(container).to receive(:running?).and_return(false)
      expect(container).not_to receive(:stop!)
      subject.perform
    end

    it 'stops container with a configured timeout' do
      expect(container).to receive(:stop_grace_period).and_return(20)
      expect(container).to receive(:stop!).with({'timeout' => 20})
      subject.perform
    end

    it 'stops container if running' do
      expect(container).to receive(:stop!).with({'timeout' => 10})
      subject.perform
    end

    it 'fails if container stop fails' do
      expect(container).to receive(:stop!).with({'timeout' => 10}).and_raise(Docker::Error::ServerError, "failed")
      expect{subject.perform}.to raise_error(Docker::Error::ServerError)
    end
  end
end
