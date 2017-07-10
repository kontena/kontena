
describe Kontena::ServicePods::Starter do

  let(:service_id) { 'service-1' }
  let(:subject) { described_class.new(service_id, 1) }

  describe '#perform' do

    let(:container) do
      double(:container, :running? => false, :name_for_humans => 'foo/bar-1')
    end

    before(:each) do
      allow(subject).to receive(:get_container).and_return(container)
    end

    it 'does nothing if container is running' do
      allow(container).to receive(:running?).and_return(true)
      expect(container).to_not receive(:restart!)
      subject.perform
    end

    it 'restarts container if not running' do
      expect(container).to receive(:stop_grace_period).and_return(10)
      expect(container).to receive(:restart!).with({'timeout' => 10})
      subject.perform
    end

    it 'fails if container restart fails' do
      expect(container).to receive(:stop_grace_period).and_return(10)
      expect(container).to receive(:restart!).with({'timeout' => 10}).and_raise(Docker::Error::ServerError, "failed")
      expect{subject.perform}.to raise_error(Docker::Error::ServerError)
    end
  end
end
