require_relative '../../../spec_helper'

describe Kontena::Workers::EventWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue, false) }
  let(:network_adapter) { spy(:network_adapter) }

  before(:each) {
    Celluloid.boot
    allow(network_adapter).to receive(:adapter_image?).and_return(false)
    allow(Celluloid::Actor).to receive(:[])
    allow(Celluloid::Actor).to receive(:[]).with(:network_adapter).and_return(network_adapter)
  }
  after(:each) { Celluloid.shutdown }

  describe '#publish_event' do
    it 'adds event to queue' do
      expect {
        subject.publish_event(spy)
      }.to change{ subject.queue.length }.by(1)
    end

    it 'publishes event' do
      event = spy(:event)
      expect(subject.wrapped_object).to receive(:publish).with(described_class::EVENT_NAME, event)
      subject.publish_event(event)
    end

    it 'does not add event to queue if source is from network adapter' do
      event = spy(:event)
      allow(network_adapter).to receive(:adapter_image?).and_return(true)
      expect {
        subject.publish_event(event)
      }.not_to change{ subject.queue.length }
    end

    it 'does not publish event if source is from network adapter' do
      event = spy(:event)
      allow(network_adapter).to receive(:adapter_image?).and_return(true)
      expect(subject.wrapped_object).not_to receive(:publish)
      subject.publish_event(event)
    end
  end
end
