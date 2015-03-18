require_relative '../../spec_helper'

describe Kontena::QueueWorker do

  class TestWsClient

    attr_accessor :events

    def initialize
      @events = {}
    end

    def on(event, &block)
      @events[event] = block
    end

    def trigger(event)
      if @events[event]
        @events[event].call
      end
    end

    def send(msg)
    end
  end

  class TestClient
    attr_accessor :ws
    delegate :on, to: :ws

    def initialize(ws)
      self.ws = ws
    end
  end

  def wait_empty_queue(queue)
    sleep 0.00001 while queue.length > 0
  end

  let(:ws) { TestWsClient.new }
  let(:client) { TestClient.new(ws) }
  let(:subject) {
    subject = described_class.new
    subject.client = client
    subject
  }
  let(:msg) { {hello: 'world'} }

  describe '#start_queue_processing' do
    it 'returns new thread if it is not already running' do
      expect(subject.start_queue_processing).to be_instance_of(Thread)
    end

    it 'returns nil if thread is already running' do
      subject.start_queue_processing
      expect(subject.start_queue_processing).to be_nil
    end

    it 'calls client.send when queue gets data' do
      subject.start_queue_processing
      item = {foo: 'bar'}
      expect(client).to receive(:send_message).once
      subject.queue << item
      sleep 0.001
    end

    it 'resumes queue processing' do
      allow(client).to receive(:send_message)
      subject.stop_queue_processing
      2.times do
        subject.queue << msg
      end
      expect(client).not_to have_received(:send_message)
      expect(subject.queue.length).to eq(2)
      subject.start_queue_processing
      wait_empty_queue(subject.queue)
      expect(client).to have_received(:send_message).twice.with(MessagePack.dump(msg).bytes)
    end
  end

  describe '#stop_queue_processing' do
    it 'stops queue work' do
      expect(client).to receive(:send_message).twice.with(MessagePack.dump(msg).bytes)
      subject.start_queue_processing
      2.times do
        subject.queue << msg
      end
      wait_empty_queue(subject.queue)
      subject.stop_queue_processing

      3.times do
        subject.queue << msg
      end
    end
  end
end