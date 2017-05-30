
describe RpcServer, celluloid: true do

  class HelloWorld
    include Celluloid

    def initialize(grid)
    end

    def hello(msg)
      { msg: "hello #{msg}" }
    end
  end

  let(:queue) { SizedQueue.new(800) }
  let(:subject) { described_class.new(queue) }

  let(:grid) { Grid.create!(name: 'test') }

  let(:ws_client) do
    double(:ws_client)
  end

  before(:each) do
    stub_const("RpcServer::HANDLERS", {'hello' => HelloWorld})
  end

  describe '#handle_request' do
    before(:each) { allow(subject.wrapped_object).to receive(:send_message) }

    it 'calls handler and sends response back to ws_client' do
      expect(subject.wrapped_object).to receive(:send_message).with(ws_client, [1, 99, nil, {msg: 'hello world'}])
      subject.handle_request(ws_client, grid.id, [1, 99, '/hello/hello', ['world']])
    end

    it 'catches RpcServer::Error' do
      subject.handle_request(ws_client, grid.id, [1, 99, '/hello/hello', ['world']])
      allow(subject.wrapped_object.handlers[grid.id]['hello'].wrapped_object).to receive(:hello).once do
        raise RpcServer::Error.new(404, 'oh-no')
      end
      expect(subject.wrapped_object).to receive(:send_message).with(ws_client, [1, 99, hash_including(code: 404) , nil])
      subject.handle_request(ws_client, grid.id, [1, 99, '/hello/hello', ['space']])
      expect(subject.wrapped_object.handlers[grid.id].size).to eq(0)
    end

    it 'catches exceptions' do
      subject.handle_request(ws_client, grid.id, [1, 99, '/hello/hello', ['world']])
      allow(subject.wrapped_object.handlers[grid.id]['hello'].wrapped_object).to receive(:hello).once do
        raise StandardError.new('oh-no')
      end
      expect(subject.wrapped_object).to receive(:send_message).with(ws_client, [1, 99, hash_including(code: 500) , nil])
      subject.handle_request(ws_client, grid.id, [1, 99, '/hello/hello', ['space']])
      expect(subject.wrapped_object.handlers[grid.id].size).to eq(0)
    end

    it 'responses with error if handler not found' do
      expect(subject.wrapped_object).to receive(:send_message).with(
        ws_client, [1, 99, {code: 501, error: "service not implemented"}, nil]
      )
      subject.handle_request(ws_client, grid.id, [1, 99, '/foo/bar', ['world']])
    end
  end
end
