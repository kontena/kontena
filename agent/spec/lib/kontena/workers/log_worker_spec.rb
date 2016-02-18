require_relative '../../../spec_helper'

describe Kontena::Workers::LogWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue, false) }
  let(:container) { spy(:container, id: 'foo', labels: {}) }

  before(:each) do
    allow(Kontena::Workers::LogWorker).to receive(:etcd_host).and_return('127.0.0.1')
    Celluloid.boot
  end

  after(:each) { Celluloid.shutdown }

  describe '#handle_message' do
    it 'appends message to queue' do
      expect {
        subject.handle_message({})
      }.to change{ subject.queue.length }.by(1)
    end
  end

  describe '#mark_timestamps' do
    it 'calls mark_timestamp for each worker' do
      subject.workers['id1'] = true
      subject.workers['id2'] = true
      expect(subject.wrapped_object).to receive(:mark_timestamp).twice
      subject.mark_timestamps
    end
  end

  describe '#mark_timestamp' do
    it 'saves timestamp to etcd' do
      etcd = spy(:etcd)
      allow(subject.wrapped_object).to receive(:etcd).and_return(etcd)
      expect(etcd).to receive(:set)
      subject.mark_timestamp('id', Time.now.to_i)
    end
  end

  describe '#stream_container_logs' do
    it 'does nothing if worker actor exist' do
      allow(subject.wrapped_object).to receive(:etcd).and_return(spy)
      expect(Kontena::Workers::ContainerLogWorker).not_to receive(:new)
      subject.workers[container.id] = spy(:container_log_worker)
      subject.stream_container_logs(container)
    end

    it 'creates new container_log_worker actor' do
      allow(subject.wrapped_object).to receive(:etcd).and_return(spy)
      worker = spy(:container_log_worker)
      expect(Kontena::Workers::ContainerLogWorker).to receive(:new).and_return(worker)
      subject.stream_container_logs(container)
    end
  end

  describe '#stop_streaming_container_logs' do
    it 'terminates worker if it exist' do
      worker = spy(:worker, :alive? => true)
      subject.workers[container.id] = worker
      expect(worker).to receive(:terminate)
      subject.stop_streaming_container_logs(container.id)
    end
  end

  describe '#on_container_event' do
    it 'stops streaming on die' do
      expect(subject.wrapped_object).to receive(:stop_streaming_container_logs).once.with('foo')
      subject.on_container_event(double(:event, id: 'foo', status: 'die'))
      sleep 0.01
    end

    it 'starts streaming on start' do
      allow(Docker::Container).to receive(:get).and_return(container)
      expect(subject.wrapped_object).to receive(:stream_container_logs).once.with(container)
      subject.on_container_event(double(:event, id: 'foo', status: 'start'))
    end

    it 'starts streaming on create' do
      allow(Docker::Container).to receive(:get).and_return(container)
      expect(subject.wrapped_object).not_to receive(:stream_container_logs)
      subject.on_container_event(double(:event, id: 'foo', status: 'create'))
    end
  end
end
