describe Kontena::RpcClient, :celluloid => true do

  let(:ws_client) { instance_double(Kontena::WebsocketClient) }
  let(:subject) { described_class.new(ws_client) }

  before do
    allow(ws_client).to receive(:connected?).and_return(true)
  end

  describe '#request_id' do
    it 'returns random integer' do
      id = subject.request_id
      expect(id).to be_instance_of(Fixnum)
    end

    it 'retries to generate id if id is already used' do
      subject.requests[1] = double(:request)
      i = 0
      expect(subject.wrapped_object).to receive(:rand).twice do
        i += 1
      end
      subject.request_id
    end
  end

  describe '#request_with_error' do
    it "returns the response" do
      expect(ws_client).to receive(:send_request).with(Fixnum, "/test", ["foo"]) do |id, method, params|
        Celluloid.after(0.0) {
          subject.async.handle_response([1, id, nil, "foobar"])
        }
      end

      expect(subject.request_with_error("/test", ["foo"], timeout: 1.0)).to eq ["foobar", nil]
    end

    it "returns any error" do
      expect(ws_client).to receive(:send_request).with(Fixnum, "/test", ["foo"]) do |id, method, params|
        Celluloid.after(0.0) {
          subject.async.handle_response([1, id, {'code' => 500, 'message' => "test error"}, nil])
        }
      end

      expect(subject.request_with_error("/test", ["foo"], timeout: 1.0)).to eq [nil, Kontena::RpcClient::Error.new(500, "test error")]
    end

    it "returns a timeout error" do
      expect(ws_client).to receive(:send_request).with(Fixnum, "/test", ["foo"]) # do nothing..

      expect(subject.request_with_error("/test", ["foo"], timeout: 0.01)).to match [nil, Kontena::RpcClient::TimeoutError]
    end
  end
end
