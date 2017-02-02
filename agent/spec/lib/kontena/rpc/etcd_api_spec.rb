describe Kontena::Rpc::EtcdApi do
  before do
    # force etcd client to use localhost
    allow_any_instance_of(described_class).to receive(:gateway).and_return('127.0.0.1')
  end

  describe '#health' do
    it "Returns true when healthy" do
      WebMock.stub_request(:get, 'http://127.0.0.1:2379/health').to_return(
        status: 200,
        body: {'health' => "true"}.to_json,
      )

      expect(subject.health).to eq health: true
    end

    it "Returns false when unhealthy" do
      WebMock.stub_request(:get, 'http://127.0.0.1:2379/health').to_return(
        status: 503,
        body: {'health' => "false"}.to_json,
      )

      expect(subject.health).to eq health: false
    end

    it "Returns error when unhealthy" do
      WebMock.stub_request(:get, 'http://127.0.0.1:2379/health').to_return(
        status: 500,
        headers: {
          'Content-Type' => 'application/json',
        },
        body: {'message' => "unhealthy"}.to_json,
      )

      expect(subject.health).to eq error: "unhealthy"
    end

    it "Returns error when down" do
      WebMock.stub_request(:get, 'http://127.0.0.1:2379/health').to_raise(Errno::ECONNREFUSED.new("Failed to open TCP connection to 172.17.0.1:2379"))

      expect(subject.health).to eq error: "Connection refused - Failed to open TCP connection to 172.17.0.1:2379"
    end
  end
end
