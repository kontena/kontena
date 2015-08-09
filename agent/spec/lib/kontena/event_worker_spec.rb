require_relative '../../spec_helper'

describe Kontena::EventWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue) }


  describe '#publish_event' do
    it 'adds event to queue' do
      expect {
        subject.publish_event(spy)
      }.to change{ subject.queue.length }.by(1)
    end

    it 'notifies observers' do
      observer = spy(:observer)
      received = false
      Kontena::Pubsub.subscribe('container:event') {|event|
        received = true
        observer.update(event)
      }
      event = spy(:event)
      expect(observer).to receive(:update).once.with(event)
      subject.publish_event(event)
      Timeout::timeout(1){ sleep 0.01 until received }
    end
  end
end
