describe Kontena::Rpc::EtcdApi do
  before do
    # force etcd client to use localhost
    allow_any_instance_of(described_class).to receive(:gateway).and_return('127.0.0.1')
  end

  describe '#health' do
    it "Returns true when healthy" do
      WebMock.stub_request(:get, 'http://127.0.0.1:2379/health').to_return(
        status: 200,
        headers: {
          'Content-Type' => 'application/json',
        },
        body: {'health' => true}.to_json,
      )

      expect(subject.health).to eq health: true
    end

    it "Returns error when unhealthy" do
      WebMock.stub_request(:get, 'http://127.0.0.1:2379/health').to_return(
        status: 500,
        headers: {
          'Content-Type' => 'application/json',
        },
        body: {'message' => 'unhealthy'}.to_json,
      )

      expect(subject.health).to eq error: 'unhealthy'
    end
  end
end
