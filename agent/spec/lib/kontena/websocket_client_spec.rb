require_relative '../../spec_helper'

describe Kontena::WebsocketClient do

  let(:subject) { described_class.new('', '')}

  before(:each) {
    Celluloid.boot
    allow(subject).to receive(:host_id).and_return('ABCD')
  }
  after(:each) { Celluloid.shutdown }

  around(:each) do |example|
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

  describe '#on_close' do
    let(:event) { Faye::WebSocket::API::CloseEvent.new('close', {}) }

    it 'publishes event' do
      expect(Celluloid::Notifications).to receive(:publish)
      subject.on_close(event)
    end

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

    it 'cancels ping timer' do
      timer = spy(:timer)
      allow(subject).to receive(:ping_timer).and_return(timer)
      expect(timer).to receive(:cancel)
      subject.on_close(event)
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
end
