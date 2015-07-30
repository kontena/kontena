require_relative '../spec_helper'

describe MongoPubsub do

  let(:channel) { 'test_channel' }

  describe '.publish' do
    it 'sends message to channel subscribers' do
      spy = spy(:listener)
      threads = []
      3.times do
        threads << Thread.new{
          described_class.subscribe(channel) {|sub|
            sub.on_message{|msg|
              spy.save(msg)
              sub.terminate
            }
          }
        }
      end
      threads << Thread.new{
        described_class.subscribe('other') {|sub|
          sub.on_message(0.1){|msg|
            spy.save(msg)
            sub.terminate
          }
        }
      }
      msg = {'hello' => 'world'}
      expect(spy).to receive(:save).exactly(3).times.with(msg)
      described_class.publish(channel, msg)
      threads.each(&:join)
    end
  end
end