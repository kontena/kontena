require_relative '../../../spec_helper'

describe Kontena::Workers::ContainerLogWorker do

  let(:container) { spy(:container) }
  let(:subject) { described_class.new(container, 0, false) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#stream_logs' do
    it 'starts to stream container logs' do
      expect(container).to receive(:streaming_logs).once.with(hash_including('tail' => 0))
      subject.stream_logs
    end

    it 'starts to stream logs from given timestamp' do
      since = (Time.now - 60).to_i
      expect(container).to receive(:streaming_logs).once.with(hash_including('since' => since, 'tail' => 'all'))
      subject.stream_logs(since)
    end
  end

  describe '#on_message' do
    it 'passes message to :log_worker actor' do
      actor = spy(:log_worker)
      expect(Celluloid::Actor).to receive(:[]).with(:log_worker).once.and_return(actor)
      expect(actor).to receive(:handle_message).once
      subject.on_message('id', 'stdout', 'log message')
    end
  end
end
