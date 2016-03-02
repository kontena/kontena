require_relative '../../spec_helper'

describe Kontena::WebsocketClient do

  let(:subject) { described_class.new('', '')}

  before(:each) { Celluloid.boot }
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

  describe '#on_open' do
    it 'sets state to connected' do
      expect(subject.connected?).to be_falsey
      subject.on_open(spy)
      expect(subject.connected?).to be_truthy
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
