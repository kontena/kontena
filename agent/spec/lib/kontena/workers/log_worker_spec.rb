
describe Kontena::Workers::LogWorker do
  include RpcClientMocks

  let(:subject) { described_class.new(false) }
  let(:container) { spy(:container, id: 'foo', labels: {}) }
  let(:etcd) { spy(:etcd) }

  before(:each) do
    Celluloid.boot
    mock_rpc_client
    allow(subject.wrapped_object).to receive(:etcd).and_return(etcd)
    allow(subject.wrapped_object).to receive(:finalize)
  end

  after(:each) { Celluloid.shutdown }

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
    it 'sets #queue_processing? to true' do
      allow(subject.wrapped_object).to receive(:async).and_return(spy)
      subject.on_connect('topic', {})
      expect(subject.queue_processing?).to be_truthy
    end
  end

  describe '#on_disconnect' do
    it 'sets #queue_processing? to false' do
      allow(subject.wrapped_object).to receive(:async).and_return(spy)
      subject.on_disconnect('topic', {})
      expect(subject.queue_processing?).to be_falsey
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
      expect(Celluloid::Actor).to receive(:kill).with(worker).once
      subject.stop_streaming_container_logs(container.id)
    end
  end

  describe '#on_container_event' do
    it 'stops streaming on die' do
      expect(subject.wrapped_object).to receive(:stop_streaming_container_logs).once.with('foo')
      subject.on_container_event('topic', double(:event, id: 'foo', status: 'die'))
      sleep 0.01
    end

    it 'starts streaming on start' do
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(subject.wrapped_object).to receive(:queue_processing?).and_return(true)
      expect(container).to receive(:skip_logs?).and_return(false)
      expect(subject.wrapped_object).to receive(:stream_container_logs).once.with(container)
      subject.on_container_event('topic', double(:event, id: 'foo', status: 'start'))
    end

    it 'does not start streaming on start if logs should be skipped' do
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(subject.wrapped_object).to receive(:queue_processing?).and_return(true)
      expect(container).to receive(:skip_logs?).and_return(true)
      expect(subject.wrapped_object).not_to receive(:stream_container_logs)
      subject.on_container_event('topic', double(:event, id: 'foo', status: 'start'))
    end

    it 'does not start streaming on create' do
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(subject.wrapped_object).to receive(:queue_processing?).and_return(true)
      expect(subject.wrapped_object).not_to receive(:stream_container_logs)
      subject.on_container_event('topic', double(:event, id: 'foo', status: 'create'))
    end
  end
end
