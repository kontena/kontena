require_relative '../spec_helper'

describe MongoPubsub do

  describe '.publish' do
    it 'sends message to channel subscribers' do
      david = spy(:david)
      lisa = spy(:lisa)
      messages = []
      subs = []
      subs << described_class.subscribe('channel1') {|msg|
        david.receive(msg)
        messages << msg
      }
      subs << described_class.subscribe('channel2') {|msg|
        lisa.receive(msg)
        messages << msg
      }
      channel1_msg = {'hello' => 'world'}
      channel2_msg = {'hello' => 'universe'}
      expect(david).to receive(:receive).once.with(channel1_msg)
      expect(lisa).to receive(:receive).once.with(channel2_msg)
      described_class.publish('channel1', channel1_msg)
      described_class.publish('channel2', channel2_msg)

      Timeout::timeout(1) do
        sleep 0.01 until messages.size == 2
      end
      subs.each(&:terminate)
    end

    it 'quarantees message ordering' do
      expected_mailbox = []
      mailbox1 = []
      mailbox2 = []
      sub1 = described_class.subscribe('channel1') {|msg|
        mailbox1 << msg
      }
      sub2 = described_class.subscribe('channel1') {|msg|
        mailbox2 << msg
      }
      100.times do |i|
        msg = {'i' => i}
        expected_mailbox << msg
        described_class.publish('channel1', msg)
      end
      sleep 0.01 until mailbox1.size == 100 && mailbox2.size == 100
      expect(mailbox1).to eq(expected_mailbox)
      expect(mailbox2).to eq(expected_mailbox)
      sub1.terminate
      sub2.terminate
    end

    it 'cleanups threads' do
      GC.start

      sub1 = described_class.subscribe('channel1') {|msg| }
      sub2 = described_class.subscribe('channel1') {|msg| }
      sub1.terminate
      sub2.terminate

      thread_count = Thread.list.count

      sub1 = described_class.subscribe('channel1') {|msg| }
      sub2 = described_class.subscribe('channel1') {|msg| }
      sub1.terminate
      sub2.terminate

      GC.start
      expect(thread_count == Thread.list.count).to be_truthy
    end
  end
end
