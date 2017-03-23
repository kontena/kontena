
describe Kontena::RpcServer do

  class HelloWorld
    def hello(msg)
      { msg: "hello #{msg}" }
    end
  end

  let(:ws_client) do
    double(:ws_client)
  end

  before(:each) do
    stub_const("Kontena::RpcServer::HANDLERS", {'hello' => HelloWorld})
    Celluloid.boot
  end

  after(:each) { Celluloid.shutdown }

  after(:each) { Celluloid.shutdown }

  describe '#handle_request' do
    it 'calls handler and sends response back to ws_client' do
      expect(subject.wrapped_object).to receive(:send_message).with(ws_client, [1, 99, nil, {msg: 'hello world'}])
      subject.handle_request(ws_client, [1, 99, '/hello/hello', ['world']])
    end

    it 'responses with error if handler not found' do
      expect(subject.wrapped_object).to receive(:send_message).with(
        ws_client, [1, 99, {code: 501, error: "service not implemented"}, nil]
      )
      subject.handle_request(ws_client, [1, 99, '/foo/bar', ['world']])
    end
  end
end
