require_relative '../../spec_helper'

describe Kontena::ContainerInfoWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue) }

  describe '#start!' do
    it 'returns thread' do
      allow(subject).to receive(:publish_node_info)
      allow(Docker::Container).to receive(:all).and_return([])
      expect(subject.start!).to be_instance_of(Thread)
    end

    it 'calls #publish_node_info' do
      expect(subject).to receive(:publish_node_info).once
      allow(Docker::Container).to receive(:all).and_return([])
      thread = subject.start!
      sleep 0.001
      thread.kill
    end
  end

  describe '#publish_node_info' do
    before(:each) do
      allow(Net::HTTP).to receive(:get).and_return('127.0.0.1')
      allow(Docker).to receive(:info).and_return({
        'Name' => 'node-1',
        'Labels' => nil,
        'ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS'
      })
    end

    it 'adds node info to queue' do
      expect {
        subject.publish_node_info
      }.to change{ subject.queue.length }.by(1)
    end

    it 'contains docker id' do
      subject.publish_node_info
      info = subject.queue.pop
      expect(info[:data]['ID']).to eq('U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS')
    end

    it 'contains public ip' do
      subject.publish_node_info
      info = subject.queue.pop
      expect(info[:data]['PublicIp']).to eq('127.0.0.1')
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
      container = spy(:container)
      expect(Docker::Container).to receive(:get).once.and_return(container)
      expect(subject).to receive(:publish_info).with(container)
      subject.on_container_event(event)
    end

    it 'publishes destroy event if container is not found' do
      event = double(:event, status: 'start', id: 'foo')
      expect(Docker::Container).to receive(:get).once.and_raise(Docker::Error::NotFoundError)
      expect(subject).to receive(:publish_destroy_event).with(event)
      subject.on_container_event(event)
    end

    it 'logs error on unknown exception' do
      event = double(:event, status: 'start', id: 'foo')
      expect(Docker::Container).to receive(:get).once.and_raise(StandardError)
      expect(subject.logger).to receive(:error).once
      subject.on_container_event(event)
    end
  end

  describe '#publish_info' do
    it 'publishes event to queue' do
      subject.publish_info(spy(:container))
      expect(queue.length).to eq(1)
    end

    it 'publishes valid message' do
      container = double(:container, json: {'Config' => {}})
      allow(subject).to receive(:node_info).and_return({'ID' => 'host_id'})
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
