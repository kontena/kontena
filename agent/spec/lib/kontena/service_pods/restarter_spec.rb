
describe Kontena::ServicePods::Restarter do

  let(:service_id) { 'service-id' }
  let(:subject) { described_class.new(service_id, 1) }

  describe '#perform' do

    let(:container) do
      double(:container, :running? => true, :name_for_humans => 'foo/bar-1')
    end

    before(:each) do
      allow(subject).to receive(:get_container).and_return(container)
    end

    it 'restarts container if running' do
      expect(container).to receive(:restart).with({'timeout' => 10})
      subject.perform
    end

    it 'does not start container if not running' do
      allow(container).to receive(:running?).and_return(false)
      expect(container).not_to receive(:start)
      subject.perform
    end
  end
end
