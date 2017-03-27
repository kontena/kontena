describe Rpc::GridSerializer do
  subject { described_class.new(grid) }

  context "for a minimal grid" do
    let(:grid) { Grid.create!(name: 'test-grid') }

    it "serializs all fields" do
      expect(subject.to_hash).to eq(
        id: 'test-grid',
        name: 'test-grid',
        initial_size: 1,
        trusted_subnets: [],
        subnet: "10.81.0.0/16",
        supernet: "10.80.0.0/12",
        stats: {
          statsd: nil,
        },
        logs: nil,
      )
    end
  end

  context "for a grid with stats and logs" do
    let(:grid) {
      Grid.create!(
        name: 'test-grid',
        stats: {
          'statsd' => { 'server' => '127.0.0.2', 'port' => 8125 },
        },
        grid_logs_opts: GridLogsOpts.new(forwarder: 'fluentd', opts: { 'fluentd-address' => '127.0.0.1'}),
      )
    }

    it "serializes the statsd field" do
      expect(subject.to_hash[:stats][:statsd]['server']).to eq '127.0.0.2'
      expect(subject.to_hash[:stats][:statsd]['port']).to eq 8125
    end

    it "serializes the logs fields" do
      expect(subject.to_hash[:logs][:forwarder]).to eq 'fluentd'
      expect(subject.to_hash[:logs][:opts]).to eq({'fluentd-address' => '127.0.0.1'})
    end
  end
end
