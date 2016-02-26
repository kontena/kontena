require_relative '../../../spec_helper'

describe Kontena::Workers::ContainerInfoWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue, false) }

  before(:each) do
    Celluloid.boot
    allow(Docker).to receive(:info).and_return({
      'Name' => 'node-1',
      'Labels' => nil,
      'ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS'
    })
  end

  after(:each) do
    Celluloid.shutdown
  end

  describe '#start' do
    it 'calls #publish_all_containers' do
      allow(subject.wrapped_object).to receive(:publish_all_containers)
      subject.start
    end
  end

  describe '#on_container_event' do
    it 'does nothing if status == destroy' do
      event = double(:event, status: 'destroy')
      expect(Docker::Container).not_to receive(:get)
      subject.on_container_event(event)
    end

    it 'fetches container info' do
      event = double(:event, status: 'start', id: 'foo')
      container = spy(:container, :config => {'Image' => 'foo/bar:latest'})
      expect(Docker::Container).to receive(:get).once.and_return(container)
      expect(subject.wrapped_object).to receive(:publish_info).with(container)
      subject.on_container_event(event)
    end

    it 'publishes destroy event if container is not found' do
      event = double(:event, status: 'start', id: 'foo')
      expect(Docker::Container).to receive(:get).once.and_raise(Docker::Error::NotFoundError)
      expect(subject.wrapped_object).to receive(:publish_destroy_event).with(event)
      subject.on_container_event(event)
    end

    it 'logs error on unknown exception' do
      event = double(:event, status: 'start', id: 'foo')
      expect(Docker::Container).to receive(:get).once.and_raise(StandardError)
      expect(subject.wrapped_object.logger).to receive(:error).once
      subject.on_container_event(event)
    end
  end

  describe '#publish_info' do
    it 'publishes event to queue' do
      subject.publish_info(spy(:container, json: {'Config' => {}}))
      expect(queue.length).to eq(1)
    end

    it 'publishes valid message' do
      container = double(:container, json: {'Config' => {}})
      allow(subject.wrapped_object).to receive(:node_info).and_return({'ID' => 'host_id'})
      subject.publish_info(container)
      valid_event = {
          event: 'container:info',
          data: {
              node: 'host_id',
              container: {
                  'Config' => {}
              }
          }
      }
      expect(queue.length).to eq(1)
      item = queue.pop
      expect(item).to eq(valid_event)
    end
  end
end
