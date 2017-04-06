module RpcClientMocks

  def self.included(base)
    base.let(:rpc_client) { instance_double(Kontena::RpcClient) }
  end

  def mock_rpc_client
    allow(subject.wrapped_object).to receive(:rpc_client).and_return(rpc_client)
    allow(rpc_client).to receive(:async).and_return(rpc_client)
    allow(rpc_client).to receive(:future).and_return(rpc_client)
  end

  def rpc_future(value)
    double(:rpc_future, value: value)
  end
end
