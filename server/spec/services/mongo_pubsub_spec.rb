require_relative '../spec_helper'

describe MongoPubsub do

  describe '.publish' do
    it 'sends message to channel subscribers' do
      david = spy(:david)
      lisa = spy(:lisa)
      threads = []
      subs = []
      threads << Thread.new{
        described_class.subscribe('channel1') {|sub|
          subs << sub
          sub.on_message(1){|msg|
            david.receive(msg)
            sub.terminate
          }
        }
      }
      threads << Thread.new{
        described_class.subscribe('channel2') {|sub|
          subs << sub
          sub.on_message(1){|msg|
            lisa.receive(msg)
            sub.terminate
          }
        }
      }
      channel1_msg = {'hello' => 'world'}
      channel2_msg = {'hello' => 'universe'}
      sleep 0.001 until subs.size == 2
      expect(david).to receive(:receive).once.with(channel1_msg)
      expect(lisa).to receive(:receive).once.with(channel2_msg)
      described_class.publish('channel1', channel1_msg)
      described_class.publish('channel2', channel2_msg)
      threads.each(&:join)
    end
  end
end
