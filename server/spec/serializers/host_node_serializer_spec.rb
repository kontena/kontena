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
        connected_at: nil,
        disconnected_at: nil,
        status: 'offline',
        has_token: false,
        updated: false,
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
        overlay_ip: "10.81.0.1",
        agent_version: nil,
        availability: "active",
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
        resource_usage: nil,
        network_drivers: [],
        volume_drivers: []
      )
    end
  end

  describe '#peer_ips' do
    it 'returns empty array by default' do
      expect(subject.peer_ips).to eq([])
    end

    it 'returns peer ips' do
      peer = grid.create_node!('peer-node',
        node_id: 'abcd',
        private_ip: '192.168.66.103'
      )
      expect(subject.peer_ips).to eq([peer.private_ip])
    end

    it 'does not return duplicate peer ips' do
      2.times do |i|
        grid.create_node!('peer-node',
          node_id: "abcd-#{i}",
          private_ip: '192.168.66.103'
        )
      end
      peer = grid.create_node!('peer-node',
        node_id: 'abcd',
        private_ip: '192.168.66.104'
      )
      expect(subject.peer_ips).to eq(['192.168.66.103', peer.private_ip])
    end
  end
end