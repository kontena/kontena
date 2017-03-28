
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

    it 'restarts container if not running' do
      expect(container).to receive(:restart).with({'timeout' => 10})
      subject.perform
    end
  end
end
