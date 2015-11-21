require_relative '../../spec_helper'

describe Kontena::Pubsub do
  before(:each) {
    Celluloid.shutdown
    Celluloid.boot
    described_class.clear!
  }
  after(:each) {
    described_class.clear!
  }

  describe '.subscribe' do
    it 'adds subscription' do
      expect {
        described_class.subscribe('foo') {|sub| p msg}
      }.to change{ described_class.subscriptions.size }.by(1)
    end
  end

  describe '.publish' do
    it 'sends message to channel subscribers' do
      messages = []
      2.times do
        described_class.subscribe('foo') {|msg|
          messages << msg
        }
      end
      described_class.subscribe('bar') {|msg|
        messages << msg
      }
      described_class.publish('foo', 'test')
      sleep 0.01
      expect(messages.size).to eq(2)
    end
  end

  describe '.clear!' do
    it 'removes all subscriptions' do
      expect(described_class.subscriptions.size).to eq(0)
      described_class.subscribe('foo') {|mag| p msg }
      described_class.clear!
      sleep 0.01
      expect(described_class.subscriptions.size).to eq(0)
    end
  end
end
