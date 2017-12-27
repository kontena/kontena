require_relative '../spec_helper'

describe EventStream do

  let(:klass) { Class.new { include Mongoid::Document; include EventStream } }
  let(:subject) { klass.new }
  let(:serializer) do
    serializer = double
    allow(serializer).to receive(:to_hash).and_return({})
    serializer
  end

  describe '#publish_create_event' do
    it 'serializes object to json' do
      serializer_class = double
      allow(subject).to receive(:find_serializer_class).and_return(serializer_class)
      allow(subject).to receive(:publish_async)

      expect(serializer_class).to receive(:new).with(subject).and_return(serializer)
      expect(serializer).to receive(:to_hash).once
      subject.publish_create_event
    end

    it 'calls publish_async with create event' do
      allow(subject).to receive(:find_serializer).and_return(serializer)
      event = {
        event: 'create',
        type: klass.name,
        object: {}
      }
      expect(subject).to receive(:publish_async).with(event).once
      subject.publish_create_event
    end
  end

  describe '#publish_update_event' do
    it 'serializes object to hash' do
      serializer_class = double
      allow(subject).to receive(:find_serializer_class).and_return(serializer_class)
      allow(subject).to receive(:publish_async)

      expect(serializer_class).to receive(:new).with(subject).and_return(serializer)
      expect(serializer).to receive(:to_hash).once
      subject.publish_create_event
    end

    it 'calls publish_async with update event' do
      allow(subject).to receive(:find_serializer).and_return(serializer)
      event = {
        event: 'update',
        type: klass.name,
        object: {}
      }
      expect(subject).to receive(:publish_async).with(event).once
      subject.publish_update_event
    end
  end

  describe '#publish_destroy_event' do
    it 'serializes object to hash' do
      serializer_class = double
      allow(subject).to receive(:find_serializer_class).and_return(serializer_class)
      allow(subject).to receive(:publish_async)

      expect(serializer_class).to receive(:new).with(subject).and_return(serializer)
      expect(serializer).to receive(:to_hash).once
      subject.publish_create_event
    end

    it 'calls publish_async with delete event' do
      allow(subject).to receive(:find_serializer).and_return(serializer)
      event = {
        event: 'delete',
        type: klass.name,
        object: {}
      }
      expect(subject).to receive(:publish_async).with(event).once
      subject.publish_destroy_event
    end
  end

  describe '#publish_async' do
    it 'publishes pub sub message to EventStream channel' do
      expect(MasterPubsub).to receive(:publish_async).with(EventStream.channel, {}).once
      subject.publish_async({})
    end

    it 'does not publish message if MasterPubsub is not started' do
      expect(MasterPubsub).to receive(:started?).and_return(false)
      expect(MasterPubsub).not_to receive(:publish_async).with(EventStream.channel, {})
      subject.publish_async({})
    end
  end
end
