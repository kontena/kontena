
describe Kontena::Workers::LogWorker, :celluloid => true do
  include RpcClientMocks

  let(:subject) { described_class.new(false) }
  let(:etcd) { instance_double(Etcd::Client) }

  before(:each) do
    mock_rpc_client
    allow(subject.wrapped_object).to receive(:etcd).and_return(etcd)
    allow(subject.wrapped_object).to receive(:finalize)
  end

  describe '#start' do
    before(:each) do
      allow(Celluloid::Actor).to receive(:[]).with(:etcd_launcher).and_return(double(running?: true))
    end
    it 'starts log streaming for container' do
      expect(Docker::Container).to receive(:all).and_return([double(skip_logs?: false)])
      expect(subject.wrapped_object).to receive(:stream_container_logs)

      subject.start
    end

    it 'does not start log streaming for container with skip logs set' do
      expect(Docker::Container).to receive(:all).and_return([double(skip_logs?: true)])
      expect(subject.wrapped_object).not_to receive(:stream_container_logs)

      subject.start
    end

    it 'does not start log streaming for MIA container' do
      c = double
      expect(c).to receive(:skip_logs?).and_raise(Docker::Error::NotFoundError)
      expect(Docker::Container).to receive(:all).and_return([c])
      expect(subject.wrapped_object).not_to receive(:stream_container_logs)

      subject.start
    end
  end

  describe '#on_connect' do
    it 'starts' do
      allow(subject.wrapped_object).to receive(:start)
      subject.on_connect('topic', {})
    end
  end

  describe '#on_disconnect' do
    it 'stops' do
      allow(subject.wrapped_object).to receive(:stop)
      subject.on_disconnect('topic', {})
    end
  end

  describe '#stop_streaming' do
    it 'calls mark_timestamp for each worker' do
      worker1 = subject.workers['id1'] = double(:worker1, alive?: true)
      worker2 = subject.workers['id2'] = double(:worker2, alive?: true)

      expect(Celluloid::Actor).to receive(:kill).with(worker1)
      expect(etcd).to receive(:set).with('/kontena/log_worker/containers/id1', {value: Integer, ttl: Integer})
      expect(Celluloid::Actor).to receive(:kill).with(worker2)
      expect(etcd).to receive(:set).with('/kontena/log_worker/containers/id2', {value: Integer, ttl: Integer})

      subject.stop_streaming

      expect(subject).to_not be_streaming
    end

    it 'marks timestamp from queue' do
      time = Time.now.utc - 60
      subject.queue << {
        id: 'id1',
        time: time.xmlschema
      }
      worker1 = subject.workers['id1'] = double(:worker1, alive?: true)

      expect(Celluloid::Actor).to receive(:kill).with(worker1)
      expect(etcd).to receive(:set).with('/kontena/log_worker/containers/id1', {value: time.to_i, ttl: Integer})

      subject.stop_streaming

      expect(subject).to_not be_streaming
    end
  end

  describe '#mark_timestamp' do
    it 'saves timestamp to etcd' do
      expect(etcd).to receive(:set).with('/kontena/log_worker/containers/id', {value: Integer, ttl: Integer})

      subject.mark_timestamp('id', Time.now.to_i)
    end
  end

  describe '#stream_container_logs' do
    let(:container) { double(:container,
      id: 'foo',
    ) }

    it 'does nothing if worker actor exist' do
      expect(Kontena::Workers::ContainerLogWorker).not_to receive(:new)
      subject.workers[container.id] = spy(:container_log_worker)
      subject.stream_container_logs(container)
    end

    context 'without any etcd key' do
      before do
        allow(etcd).to receive(:get).with('/kontena/log_worker/containers/foo').and_raise(Etcd::KeyNotFound)
      end

      it 'creates new container_log_worker actor' do
        worker = spy(:container_log_worker)
        expect(Kontena::Workers::ContainerLogWorker).to receive(:new).with(container, Array).and_return(worker)
        subject.stream_container_logs(container)
      end
    end
  end

  describe '#stop_streaming_container_logs' do
    it 'terminates worker if it exist' do
      worker = double(:worker, :alive? => true)
      subject.workers['foo'] = worker
      expect(Celluloid::Actor).to receive(:kill).with(worker).once
      subject.stop_streaming_container_logs('foo')
    end
  end

  describe '#on_container_event' do
    let(:skip_logs?) { false }
    let(:container) { double(:container,
      id: 'foo',
      name: 'test-1',
      labels: {'io.kontena.container.type' => 'test'},
      skip_logs?: skip_logs?,
    ) }

    before do
      allow(Docker::Container).to receive(:get).with('foo').and_return(container)
    end

    context 'when not streaming' do
      it 'marks start time' do
        expect(subject.wrapped_object).to receive(:mark_timestamp).with('foo', Integer)

        subject.on_container_event('topic', double(:event, id: 'foo', status: 'start'))
      end

      it 'stops streaming on die' do
        expect(subject.wrapped_object).to receive(:stop_streaming_container_logs).once.with('foo')

        subject.on_container_event('topic', double(:event, id: 'foo', status: 'die'))
      end
    end

    context 'when streaming' do
      before do
        allow(subject.wrapped_object).to receive(:streaming?).and_return(true)
      end

      it 'starts streaming on start' do
        expect(subject.wrapped_object).to receive(:stream_container_logs).once.with(container)

        subject.on_container_event('topic', double(:event, id: 'foo', status: 'start'))
      end

      context 'with skip_logs' do
        let(:skip_logs?) { true }

        it 'does not start streaming on start if logs should be skipped' do
          expect(subject.wrapped_object).not_to receive(:stream_container_logs)
          expect(subject.wrapped_object).to receive(:mark_timestamp).with('foo', Integer) # XXX: why?

          subject.on_container_event('topic', double(:event, id: 'foo', status: 'start'))
        end
      end

      it 'does not start streaming on create' do
        expect(subject.wrapped_object).not_to receive(:stream_container_logs)

        subject.on_container_event('topic', double(:event, id: 'foo', status: 'create'))
      end
    end
  end
end
