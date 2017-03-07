
describe Kontena::Workers::ContainerLogWorker do

  let(:container) { spy(:container) }
  let(:queue) { Queue.new }
  let(:subject) { described_class.new(container, queue) }

  before(:each) { Celluloid.boot }
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
  end
end
