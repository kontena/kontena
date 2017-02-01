require_relative '../../spec_helper'

describe Kontena::WebsocketClient do

  let(:subject) { described_class.new('', '')}

  before(:each) {
    Celluloid.boot
    allow(subject).to receive(:host_id).and_return('ABCD')
    allow(subject).to receive(:labels).and_return(['region=test'])
  }
  after(:each) { Celluloid.shutdown }

  around(:each, :em => true) do |example|
    EM.run {
      example.run
      EM.stop
    }
  end

  describe '#connected?' do
    it 'returns false by default' do
      expect(subject.connected?).to eq(false)
    end

    it 'returns true if connection is established' do
      subject.on_open(spy(:event))
      expect(subject.connected?).to eq(true)
    end
  end

  describe '#connect' do
    it 'sets connecting to true' do
      expect {
        subject.connect
      }.to change{ subject.connecting? }.from(false).to(true)
    end

    it 'sets connected to false' do
      subject.on_open(spy)
      expect {
        subject.connect
      }.to change{ subject.connected? }.from(true).to(false)
    end
  end

  describe '#on_open' do
    it 'sets connected to true' do
      expect(subject.connected?).to be_falsey
      subject.on_open(spy)
      expect(subject.connected?).to be_truthy
    end

    it 'sets connecting to false' do
      subject.connect
      expect(subject.connecting?).to be_truthy
      subject.on_open(spy)
      expect(subject.connecting?).to be_falsey
    end

    it 'cancels ping timer' do
      timer = spy(:timer)
      allow(subject).to receive(:ping_timer).and_return(timer)
      expect(timer).to receive(:cancel)
      subject.on_open(spy)
    end
  end

  describe '#on_error' do
    context "For a server that is ECONNREFUSED" do
      subject do
        described_class.new('ws://127.0.0.1:1337', 'test-token')
      end

      it "logs an error", :em => false do
        expect(subject).to receive(:error).with(/connection refused/) do |event|
          EM.stop
        end

        # XXX: EM will segfault if the mock raises
        # =>   https://github.com/eventmachine/eventmachine/issues/765
        EM.run {
          subject.connect
        }
      end


    end
  end

  describe '#on_close' do
    let(:event) { Faye::WebSocket::API::CloseEvent.new('close', {}) }

    it 'sets connected to false' do
      subject.on_open(spy)
      expect {
        subject.on_close(event)
      }.to change{ subject.connected? }.from(true).to(false)
    end

    it 'sets connecting to false' do
      subject.connect
      expect {
        subject.on_close(event)
      }.to change{ subject.connecting? }.from(true).to(false)
    end

    it 'handles 4001 error code' do
      event = Faye::WebSocket::API::CloseEvent.new('close', code: 4001)
      expect(subject).to receive(:handle_invalid_token).once
      subject.on_close(event)
    end

    it 'handles 4010 error code' do
      event = Faye::WebSocket::API::CloseEvent.new('close', code: 4010)
      expect(subject).to receive(:handle_invalid_version).once
      subject.on_close(event)
    end
  end

  describe '#close' do
    let :ws do
      instance_double(Faye::WebSocket::Client)
    end

    before do
      allow(subject).to receive(:ws).and_return(ws)
    end

    it 'publishes event', :em => true do
      expect(Celluloid::Notifications).to receive(:publish).with('websocket:disconnect', nil)
      expect(ws).to receive(:close).with(1000)
      subject.close
    end

    context "for a connected websocket", :em => true do
      let :open_event do
        double(:open_event)
      end
      let :close_event do
        double(:close_event, code: 1006)
      end

      let :close_timer do
        instance_double(EM::Timer)
      end

      before do
        subject.on_open open_event

        expect(subject).to be_connected
        expect(subject).to_not be_connecting
      end

      it 'sets connection as disconnected if it immediately emits :close' do
        expect(Celluloid::Notifications).to receive(:publish).with('websocket:disconnect', nil)

        expect(ws).to receive(:close).with(1000) { subject.on_close close_event }
        subject.close

        expect(subject).to_not be_connected
        expect(subject).to_not be_connecting
      end

      it 'sets connection to closed if it blocks' do
        expect(Celluloid::Notifications).to receive(:publish).with('websocket:disconnect', nil)

        expect(ws).to receive(:close).with(1000) { }
        expect(EM::Timer).to receive(:new) { |timeout, &block| @close_block = block; close_timer }

        subject.close

        expect(subject).to be_connected
        expect(subject).to_not be_connecting

        expect(ws).to receive(:remove_all_listeners)
        expect(subject).to receive(:on_close).and_call_original
        expect(close_timer).to receive(:cancel)

        @close_block.call

        expect(subject).to_not be_connected
        expect(subject).to_not be_connecting
      end
    end
  end

  describe '#request_message?' do
    it 'returns trus on request message' do
      msg = [0, 1, 1, 1]
      expect(subject.request_message?(msg)).to be_truthy
    end

    it 'returns false if not an request message' do
      msg = [1, 1, 1, 1]
      expect(subject.request_message?(msg)).to be_falsey
    end
  end

  describe '#notification_message?' do
    it 'returns trus if notification message' do
      msg = [2, 1, 1]
      expect(subject.notification_message?(msg)).to be_truthy
    end
  end

  describe '#send_message' do
    it 'does not raise error if ws is nil' do
      allow(subject).to receive(:@ws).and_return(nil)
      expect {
        subject.send_message('foo')
      }.not_to raise_error
    end
  end
end
