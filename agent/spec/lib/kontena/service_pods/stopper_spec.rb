
describe Kontena::ServicePods::Stopper do

  let(:service_id) { 'service-id' }
  let(:subject) { described_class.new(service_id, 1) }

  describe '#perform' do

    let(:container) do
      double(:container, :running? => true, :name_for_humans => 'foo/bar-1')
    end

    before(:each) do
      allow(subject).to receive(:get_container).and_return(container)
    end

    it 'stops container' do
      expect(container).to receive(:stop).with({'timeout' => 10})
      subject.perform
    end
  end
end
