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

  describe '#start' do
    it 'starts processing events' do
      expect(subject.wrapped_object).to receive(:stream_events)
      expect(subject.wrapped_object).to receive(:process_events)
      subject.start
    end

    it 'streams and processes events' do
      times = 100
      subject
      allow(Docker::Event).to receive(:stream) {|params, &block|
        times.times {
          block.call(Docker::Event.new('status', 'id', 'from', 'time'))
        }
        sleep 0.1
        subject.stop_processing
      }
      subject.async.start
      sleep 0.1
      expect(queue.size).to eq(times)
    end
  end

  describe '#process_events' do
    it 'processes events from queue' do
      expect(subject.wrapped_object).to receive(:publish_event).exactly(2).times
      subject.async.process_events
      subject.event_queue << {msg: 'foo'}
      subject.event_queue << {msg: 'bar'}
      sleep 0.01
      subject.terminate
    end
  end

  describe '#stream_events' do
    it 'streams events from docker' do
      subject
      allow(Docker::Event).to receive(:stream) {|params, &block|
        1000.times {
          block.call({})
        }
        subject.stop_processing
      }
      subject.async.stream_events
      sleep 0.01
      expect(subject.event_queue.size).to eq(1000)
    end

    it 'retries if unknown exception occurs' do
      subject
      i = 0
      spy = spy(:spy)
      allow(Docker::Event).to receive(:stream) {|params, &block|
        spy.check
        i += 1
        raise 'foo' if i == 1
        subject.stop_processing if i == 2
      }
      expect(spy).to receive(:check).exactly(2).times
      subject.async.stream_events
      sleep 0.01
    end

    it 'retries if stream finishes' do
      subject
      i = 0
      spy = spy(:spy)
      allow(Docker::Event).to receive(:stream) {|params, &block|
        spy.check
        i += 1
        subject.stop_processing if i == 2
      }
      expect(spy).to receive(:check).exactly(2).times
      subject.async.stream_events
      sleep 0.01
    end

    it 'does not retry after exception if processing has stopped' do
      spy = spy(:spy)
      allow(Docker::Event).to receive(:stream) {|params, &block|
        spy.check
        subject.stop_processing
        raise 'foo'
      }
      expect(spy).to receive(:check).once
      subject.async.stream_events
      sleep 0.01
    end
  end

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
