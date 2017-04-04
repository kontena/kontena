
describe Kontena::RpcClient, eventmachine: true do

  let(:ws_client) { double(:ws_client) }
  let(:subject) { described_class.new(ws_client) }

  describe '#async' do
    it 'returns AsyncProxy' do
      expect(subject.async.class).to eq(Kontena::RpcClient::AsyncProxy)
    end

    it 'raises error if client does not have called method' do
      expect {
        subject.async.foobar
      }.to raise_error( ArgumentError )
    end

    it 'calls proxies call to client' do
      expect(subject).to receive(:request).with('/foo/bar', [1,2,3])
      subject.async.request('/foo/bar', [1,2,3])
      EM.run_deferred_callbacks
    end
  end

  describe '.request_id' do
    it 'returns random integer' do
      id = described_class.request_id(subject)
      expect(id).to be_instance_of(Fixnum)
    end

    it 'retries to generate id if id is already used' do
      described_class.requests[1] = double(:request)
      i = 0
      expect(described_class).to receive(:rand).twice do
        i += 1
      end
      described_class.request_id(subject)
    end
  end
end
