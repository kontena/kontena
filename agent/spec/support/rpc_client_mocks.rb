module RpcClientMocks

  def self.included(base)
    base.let(:rpc_client) { double(:rpc_client) }
  end

  def mock_rpc_client
    allow(subject.wrapped_object).to receive(:rpc_client).and_return(rpc_client)
  end
end
