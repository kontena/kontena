require_relative '../../spec_helper'

describe Kontena::Pubsub do
  
  before(:each) {
    Celluloid.boot
    described_class.clear!
  }
  after(:each) {
    described_class.clear!
    Celluloid.shutdown
  }

  describe '.subscribe' do
    it 'adds subscription' do
      expect {
        described_class.subscribe('foo') {|sub| p msg}
      }.to change{ described_class.subscriptions.size }.by(1)
    end

    it 'cleans threads' do
      GC.start
      subscriptions = []
      3.times do
        subscriptions << described_class.subscribe('foo') {|sub| p msg}
      end
      subscriptions.each{|s| s.terminate }
      thread_count = Thread.list.count

      subscriptions = []
      3.times do
        subscriptions << described_class.subscribe('foo') {|sub| p msg}
      end
      subscriptions.each{|s| s.terminate }
      GC.start
      expect(Thread.list.count == thread_count).to be_truthy
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
      subs = described_class.subscribe('bar') {|msg|
        messages << msg
      }
      described_class.publish('foo', 'test')
      sleep 0.01
      expect(messages.size).to eq(2)
      subs.terminate
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
