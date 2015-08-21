require_relative '../../spec_helper'

describe Kontena::LogWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue) }
  let(:container) { double(:container, id: 'foo', info: {'Labels' => {}}) }

  describe '#stream_container_logs' do
    it 'starts to stream container logs immediately' do
      expect(container).to receive(:streaming_logs).once
      thread = subject.stream_container_logs(container, 'all')
      sleep 0.001
      thread.kill
    end

    it 'waits 2 seconds when status is create' do
      expect(container).to receive(:streaming_logs).once
      expect(subject).to receive(:sleep).with(2)
      thread = subject.stream_container_logs(container, 'create')
      sleep 0.001
      thread.kill
    end
  end

  describe '#on_message' do
    it 'adds message to queue' do
      expect {
        subject.on_message('id', 'stdout', 'daa')
      }.to change{ subject.queue.length }.by(1)
    end

    it 'adds correct data to queue' do
      log_data = {id: 'foo123', type: 'stdout', data: 'hello world'}
      subject.on_message(log_data[:id], log_data[:type], log_data[:data])
      msg = queue.pop
      expect(msg[:event]).to eq('container:log')
      expect(msg[:data][:type]).to eq(log_data[:type])
      expect(msg[:data][:data]).to eq(log_data[:data])
      expect(msg[:data][:time]).not_to be_nil
    end
  end

  describe '#stop_streaming_container_logs' do
    it 'stops streaming thread' do
      expect(container).to receive(:streaming_logs).once
      subject.stream_container_logs(container, 'all')
      sleep 0.001
      expect {
        subject.stop_streaming_container_logs(container.id)
      }.to change{ subject.streaming_threads.length }.by(-1)
    end

    it 'does nothing on invalid id' do
      expect {
        subject.stop_streaming_container_logs('not_found')
      }.to change{ subject.streaming_threads.length }.by(0)
    end
  end

  describe '#on_container_event' do
    it 'stops streaming on stop' do
      expect(subject).to receive(:stop_streaming_container_logs).once.with('foo')
      subject.on_container_event(double(:event, id: 'foo', status: 'stop'))
      sleep 0.01
    end

    it 'stops streaming on die' do
      expect(subject).to receive(:stop_streaming_container_logs).once.with('foo')
      subject.on_container_event(double(:event, id: 'foo', status: 'die'))
      sleep 0.01
    end

    it 'starts streaming on start' do
      allow(Docker::Container).to receive(:get).and_return(container)
      expect(subject).to receive(:stream_container_logs).once.with(container, 'start')
      subject.on_container_event(double(:event, id: 'foo', status: 'start'))
    end

    it 'starts streaming on create' do
      allow(Docker::Container).to receive(:get).and_return(container)
      expect(subject).to receive(:stream_container_logs).once.with(container, 'create')
      subject.on_container_event(double(:event, id: 'foo', status: 'create'))
    end
  end
end
