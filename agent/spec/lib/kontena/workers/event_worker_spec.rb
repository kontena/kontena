
describe Kontena::Workers::EventWorker do
  include RpcClientMocks

  let(:subject) { described_class.new(false) }
  let(:network_adapter) { spy(:network_adapter) }
  let(:event) {
    {
      'Action' => 'start',
      'Actor' => {
        'Attributes' => {
          'image' => 'tianon/true',
          'name' => 'true-dat'
        },
        'ID' => 'bb2c783a32330b726f18d1eb44d80c899ef45771b4f939326e0fefcfc7e05db8'
      },
      'Type' => 'container',
      'from' => 'tianon/true',
      'id' => 'bb2c783a32330b726f18d1eb44d80c899ef45771b4f939326e0fefcfc7e05db8',
      'status' => 'start',
      'time' => 1461083270,
      'timeNano' => 1461083270652069004
    }
  }

  before(:each) {
    Celluloid.boot
    allow(network_adapter).to receive(:adapter_image?).and_return(false)
    allow(Celluloid::Actor).to receive(:[])
    allow(Celluloid::Actor).to receive(:[]).with(:network_adapter).and_return(network_adapter)
    mock_rpc_client
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
      expect(rpc_client).to receive(:notification).exactly(times).times
      subject
      allow(Docker::Event).to receive(:stream) {|params, &block|
        times.times {
          block.call(Docker::Event.new(event))
        }
        sleep 0.1
        subject.stop_processing
      }
      subject.start
      sleep 0.01 until !subject.processing?
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
      sleep 0.01 until !subject.processing?
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
      sleep 0.01 until !subject.processing?
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
      sleep 0.01 until !subject.processing?
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
      sleep 0.01 until !subject.processing?
    end
  end

  describe '#publish_event' do
    it 'sends event via rpc' do
      expect(rpc_client).to receive(:notification).with('/containers/event', [anything])
      subject.publish_event(spy)
    end

    it 'publishes event' do
      expect(rpc_client).to receive(:notification)
      event = spy(:event)
      expect(subject.wrapped_object).to receive(:publish).with(described_class::EVENT_NAME, event)
      subject.publish_event(event)
    end

    it 'does not send event if source is from network adapter' do
      event = spy(:event)
      expect(rpc_client).not_to receive(:notification)
      allow(network_adapter).to receive(:adapter_image?).and_return(true)
      subject.publish_event(event)
    end

    it 'does not publish event if source is from network adapter' do
      event = spy(:event)
      allow(network_adapter).to receive(:adapter_image?).and_return(true)
      expect(subject.wrapped_object).not_to receive(:publish)
      subject.publish_event(event)
    end
  end
end
