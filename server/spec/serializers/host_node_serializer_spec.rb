describe HostNodeSerializer do
  let(:now) { Time.new(2017, 03, 27, 11, 21, 55, '+03:00') }
  let(:grid) { Grid.create!(name: 'test-grid') }

  let(:host_node) {
    grid.create_node!('test-node',
      created_at: now,
      updated_at: now,
      node_id: 'wxyz',
    )
  }

  subject { described_class.new(host_node) }

  describe '#to_hash' do
    it "serializs object" do
      expect(subject.to_hash).to match(
        id: 'test-grid/test-node',
        connected: false,
        created_at: "2017-03-27T08:21:55Z",
        updated_at: "2017-03-27T08:21:55Z",
        last_seen_at: nil,
        name: "test-node",
        os: nil,
        engine_root_dir: nil,
        driver: nil,
        kernel_version: nil,
        labels: [],
        mem_total: nil,
        mem_limit: nil,
        cpus: nil,
        public_ip: nil,
        private_ip: nil,
        agent_version: nil,
        docker_version: nil,
        peer_ips: [],
        node_id: "wxyz",
        node_number: 1,
        initial_member: true,
        grid: {
          id: "test-grid",
          name: "test-grid",
          initial_size: 1,
          stats: {
            statsd: nil
          },
          trusted_subnets:[]
        },
        resource_usage: nil
      )
    end
  end
end