
describe Cloud::RpcServer do

  describe '#handle_request' do
    it 'returns rpc error message if unknown handler' do
      message = [0, 12345, 'unknown', []]
      result = subject.handle_request(message)
      expect(result).to eq([1, 12345, {error: 'service not implemented'}, nil])
    end

    it 'calls handler\'s method with given arguments' do
      message = [0, 12345, 'rest_request/get', ['param']]
      server_api_stub = double
      expect(Cloud::Rpc::ServerApi).to receive(:new).and_return(server_api_stub)
      expect(server_api_stub).to receive(:get).with('param').and_return({})
      result = subject.handle_request(message)
    end

    it 'returns rpc result message' do
      message = [0, 12345, 'rest_request/get', ['param']]
      server_api_stub = double
      allow(Cloud::Rpc::ServerApi).to receive(:new).and_return(server_api_stub)
      allow(server_api_stub).to receive(:get).with('param').and_return('result')
      result = subject.handle_request(message)
      expect(result).to eq([1, 12345, nil, 'result'])
    end

    it 'returns rpc error message if exception is raised' do
      message = [0, 12345, 'rest_request/get', ['param']]
      server_api_stub = double
      allow(Cloud::Rpc::ServerApi).to receive(:new).and_return(server_api_stub)
      allow(server_api_stub).to receive(:get).with('param')
        .and_raise(Cloud::RpcServer::Error.new(403, 'Forbidden'))
      result = subject.handle_request(message)
      expect(result).to eq([1, 12345, { code: 403, message: 'Forbidden', backtrace: nil }, nil])
    end
  end
end
