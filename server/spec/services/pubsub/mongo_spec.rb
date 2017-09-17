
describe Pubsub::Mongo, :celluloid => true do

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

      WaitHelper.wait_until!(timeout: 5) { messages.size == 2 }

      subs.each(&:terminate)
    end

    it 'supports hash keys with mixed symbols and strings' do
      messages = []

      sub =  described_class.subscribe('test') {|msg|
        messages << msg
      }

      described_class.publish('test', {'foo' => 'bar 1'})
      described_class.publish('test', {foo: 'bar 2'})

      WaitHelper.wait_until!(timeout: 5) { messages.size == 2 }

      expect(messages.map{|m| m[:foo]}).to eq ['bar 1', 'bar 2']
      expect(messages.map{|m| m['foo']}).to eq ['bar 1', 'bar 2']

      sub.terminate
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

    it 'handles subscribers that crash' do
      @crash = false
      @done = false
      sub1 = described_class.subscribe('test') do |msg|
        if msg[:crash]
          @crash = true
          fail msg[:crash]
        elsif msg[:done]
          @done = true
        end
      end

      described_class.publish('test', crash: false)
      described_class.publish('test', crash: 'test')
      WaitHelper.wait_until!("crashed", interval: 0.05) { @crash }
      described_class.publish('test', done: true)
      WaitHelper.wait_until!("done", interval: 0.05) { @done }

      sub1.terminate
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

    it 'should perform', performance: true do
      requests = []
      responses = []
      servers = []
      clients = []
      rounds = 100
      start_time = Time.now.to_f
      rounds.times do |i|
        servers << described_class.subscribe("server:#{i}") {|msg|
          requests << msg
          described_class.publish("client:#{msg['request']}", {:response => i})
        }
        clients << described_class.subscribe("client:#{i}") {|msg|
          responses << msg
        }
        described_class.publish_async("server:#{i}", {:request => i})
      end
      sleep 0.1 until responses.size == rounds
      end_time = Time.now.to_f
      duration = end_time - start_time
      expect(responses.size).to eq(rounds)
      expect(duration <= 2.0).to be_truthy
    end
  end
end
