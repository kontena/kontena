
describe RpcServer, celluloid: true do

  class HelloWorld
    include Celluloid

    def initialize(grid)
    end

    def hello(msg)
      { msg: "hello #{msg}" }
    end
  end

  let(:queue) { RpcServer.queue }
  let(:subject) { described_class.new(autostart: false) }
  let(:msg_id) { 99 }

  let(:grid) { Grid.create!(name: 'test') }

  before(:each) do
    stub_const("RpcServer::HANDLERS", {'hello' => HelloWorld})
  end

  describe '#handle_request' do
    it 'calls handler and sends response back to ws_client' do
      expect(subject.handle_request(grid.id, [0, msg_id, '/hello/hello', ['world']])).to eq [1, msg_id, nil, {msg: 'hello world'}]
    end

    it 'catches RpcServer::Error' do
      subject.handle_request(grid.id, [0, msg_id, '/hello/hello', ['world']])

      allow(subject.wrapped_object.handlers[grid.id]['hello'].wrapped_object).to receive(:hello).once do
        raise RpcServer::Error.new(404, 'oh-no')
      end
      expect(subject.handle_request(grid.id, [0, msg_id, '/hello/hello', ['space']])).to match [1, msg_id, hash_including(code: 404), nil]
      expect(subject.wrapped_object.handlers[grid.id].size).to eq(0)
    end

    it 'catches exceptions' do
      subject.handle_request(grid.id, [0, msg_id, '/hello/hello', ['world']])

      allow(subject.wrapped_object.handlers[grid.id]['hello'].wrapped_object).to receive(:hello).once do
        raise StandardError.new('oh-no')
      end
      expect(subject.handle_request(grid.id, [0, msg_id, '/hello/hello', ['space']])).to match [1, msg_id, hash_including(code: 500) , nil]
      expect(subject.wrapped_object.handlers[grid.id].size).to eq(0)
    end

    it 'responses with error if handler not found' do
      expect(subject.handle_request(grid.id, [1, msg_id, '/foo/bar', ['world']])).to eq [1, msg_id, {code: 501, error: "service not implemented"}, nil]
    end
  end
end
