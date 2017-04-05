
describe Kontena::RpcClientSession do

  let(:ws_client) { double(:ws_client, connected?: true) }
  let(:rpc_client) { double(:ws_client) }
  let(:subject) { described_class.new(ws_client, rpc_client) }

  describe '#notification' do
    it 'calls ws_client' do
      expect(ws_client).to receive(:send_notification)
      subject.notification('/foo', 'bar')
    end
  end

  describe '#request' do
    it 'sends request and returns response' do
      allow(ws_client).to receive(:send_request).once
      expect(ws_client).to receive(:connected?).once.and_return(true)
      allow(rpc_client).to receive(:request_id).and_return(1)
      response = nil
      t = Thread.new {
        response = subject.request('/foo', 'bar')
      }
      sleep 0.01
      subject.handle_response({ok: 1}, nil)
      t.join
      expect(response).to eq({ok: 1})
    end

    it 'throws error if response is an error' do
      allow(ws_client).to receive(:send_request).once
      expect(ws_client).to receive(:connected?).once.and_return(true)
      allow(rpc_client).to receive(:request_id).and_return(1)
      t = Thread.new {
        expect {
          subject.request('/foo', 'bar')
        }.to raise_error(Kontena::RpcClientSession::Error)
      }
      sleep 0.01
      subject.handle_response(nil, {'code' => 404, 'message' => 'not found'})
      t.join
    end
  end
end
