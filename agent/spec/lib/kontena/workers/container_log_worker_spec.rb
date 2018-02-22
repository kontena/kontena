
describe Kontena::Workers::ContainerLogWorker do

  let(:container) { spy(:container) }
  let(:queue) { Queue.new }
  let(:subject) { described_class.new(container, queue) }
  let(:fluentd_worker) { spy(:fluentd_worker) }

  before(:each) {
    Celluloid.boot
    allow(Celluloid::Actor).to receive(:[]).with(:fluentd_worker).and_return(fluentd_worker)
  }
  after(:each) { Celluloid.shutdown }

  describe '#start' do
    it 'starts to stream container logs' do
      expect(container).to receive(:streaming_logs).once.with(hash_including('tail' => 0))
      subject.start
    end

    it 'terminates itself if container goes MIA' do
      expect(container).to receive(:streaming_logs).and_raise(Docker::Error::NotFoundError)
      expect(subject.wrapped_object).to receive(:terminate)
      subject.start
    end

    it 'starts to stream logs from given timestamp' do
      since = (Time.now - 60).to_i
      expect(container).to receive(:streaming_logs).once.with(hash_including('since' => since, 'tail' => 'all'))
      subject.start(since)
    end
  end

  describe '#on_message' do
    it 'adds message to queue' do
      expect {
        subject.on_message('id', 'stdout', '2016-02-29T07:26:07.798612937Z log message')
      }.to change{ queue.length }.by(1)
    end

    it 'publishes log event' do
      expect(container).to receive(:service_name).and_return('a-service')
      expect(container).to receive(:stack_name).and_return('stack')
      expect(container).to receive(:instance_number).and_return(1)
      log = '2016-02-29T07:26:07.798612937Z log message'
      expected_log = {
        id: 'id',
        service: 'a-service',
        stack: 'stack',
        instance: 1,
        type: 'stdout',
        data: 'log message',
        time: '2016-02-29T07:26:07.798612937Z'
      }
      expect(subject.wrapped_object).to receive(:publish_log).with(expected_log)
      subject.on_message('id', 'stdout', log)
    end

    it 'throttles if queue is over throttle limit' do
      expect(queue).to receive(:size).twice.and_return(Kontena::Workers::LogWorker::QUEUE_THROTTLE + 10)
      expect(subject.wrapped_object).to receive(:sleep)
      expect {
        subject.on_message('id', 'stdout', '2016-02-29T07:26:07.798612937Z log message')
      }.to change{ queue.length }
    end

    it 'does not push message to queue if queue is full' do
      expect(queue).to receive(:size).and_return(Kontena::Workers::LogWorker::QUEUE_MAX_SIZE + 10)
      expect {
        subject.on_message('id', 'stdout', '2016-02-29T07:26:07.798612937Z log message')
      }.not_to change{ queue.length }
    end
  end
end
