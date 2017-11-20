describe Kontena::RpcClient, :celluloid => true do

  let(:ws_client) { instance_double(Kontena::WebsocketClient) }
  let(:subject) { described_class.new() }

  before do
    allow(ws_client).to receive(:connected?).and_return(true)
    allow(subject.wrapped_object).to receive(:websocket_client).and_return(ws_client)
  end

  describe '#request_id' do
    it 'returns random integer' do
      id = subject.request_id
      expect(id).to be_instance_of(Integer)
    end

    it 'retries to generate id if id is already used' do
      subject.requests[1] = double(:request)
      i = 0
      expect(subject.wrapped_object).to receive(:rand).twice do
        i += 1
      end

      expect(subject.request_id).to eq 2
    end
  end

  describe '#request' do
    it "returns the response" do
      expect(ws_client).to receive(:send_request).with(Integer, "/test", ["foo"]) do |id, method, params|
        Celluloid.after(0.0) {
          subject.async.handle_response([1, id, nil, "foobar"])
        }
      end

      expect(subject.request("/test", ["foo"], timeout: 1.0)).to eq "foobar"
    end

    it "returns any error" do
      expect(ws_client).to receive(:send_request).with(Integer, "/test", ["foo"]) do |id, method, params|
        Celluloid.after(0.0) {
          subject.async.handle_response([1, id, {'code' => 500, 'message' => "test error"}, nil])
        }
      end

      expect{subject.request("/test", ["foo"], timeout: 1.0)}.to raise_error(Kontena::RpcClient::Error, "test error")
    end

    it "returns a timeout error" do
      expect(ws_client).to receive(:send_request).with(Integer, "/test", ["foo"]) # do nothing..

      expect(subject.wrapped_object).to receive(:warn).with(Kontena::RpcClient::TimeoutError)

      expect{subject.request("/test", ["foo"], timeout: 0.01)}.to raise_error(Kontena::RpcClient::TimeoutError)
    end
  end

  context "for a very small random pool with conflicts" do
    let(:size) { 5 }
    let(:count) { size ** 2 }

    before do
      stub_const("Kontena::RpcClient::REQUEST_ID_RANGE", 1..size)

      # echo server
      allow(ws_client).to receive(:send_request).with(Integer, '/echo', [Integer]) do |id, method, params|
        Celluloid.after(0.01) {
          subject.handle_response([1, id, nil, params])
        }
      end
    end

    it "does not cause request collisions" do
      # N**2 requests with a pool of N IDs should guarantee collisions
      expect(subject.wrapped_object).to receive(:sleep).at_least(:once).and_call_original

      requests = (1..count).map{ |i|
        subject.future.request("/echo", [i], timeout: 1.0)
      }
      responses = requests.map{|f| f.value[0] }

      expect(responses).to match_array (1..count).to_a
    end
  end
end
