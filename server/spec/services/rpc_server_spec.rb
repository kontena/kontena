require_relative '../spec_helper'

describe RpcServer, celluloid: true do

  class HelloWorld

    def initialize(grid)
    end

    def hello(msg)
      { msg: "hello #{msg}" }
    end
  end

  let(:grid) { Grid.create!(name: 'test') }

  let(:ws_client) do
    double(:ws_client)
  end

  before(:each) do
    stub_const("RpcServer::HANDLERS", {'hello' => HelloWorld})
  end

  describe '#handle_request' do
    it 'calls handler and sends response back to ws_client' do
      expect(subject.wrapped_object).to receive(:send_message).with(ws_client, [1, 99, nil, {msg: 'hello world'}])
      subject.handle_request(ws_client, grid.id, [1, 99, '/hello/hello', ['world']])
    end

    it 'responses with error if handler not found' do
      expect(subject.wrapped_object).to receive(:send_message).with(
        ws_client, [1, 99, {code: 501, error: "service not implemented"}, nil]
      )
      subject.handle_request(ws_client, grid.id, [1, 99, '/foo/bar', ['world']])
    end
  end
end
