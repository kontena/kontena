
describe Kontena::Actors::ContainerCoroner do

  let(:container) do
    double(:container, id: 'dead-id', name: '/dead')
  end
  let(:subject) { described_class.new(container, false) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#investigate' do
    it 'confirms if container has gone' do
      allow(Docker::Container).to receive(:get).with(container.id).and_return(nil)
      expect(subject.wrapped_object).to receive(:confirm)
      subject.investigate
    end

    it 'does not config if container still exists' do
      allow(Docker::Container).to receive(:get).with(container.id).and_return(container)
      expect(subject.wrapped_object).not_to receive(:confirm)
      subject.investigate
    end
  end

  describe '#confirm' do
    let(:event_worker) do
      double(:event_worker)
    end

    before(:each) do
      allow(subject.wrapped_object).to receive(:event_worker).and_return(event_worker)
    end

    it 'publishes event' do
      expect(event_worker).to receive(:publish_event)
      subject.confirm
    end

    it 'terminates actor' do
      allow(event_worker).to receive(:publish_event)
      subject.confirm
      expect(subject.alive?).to be_falsey
    end
  end
end
