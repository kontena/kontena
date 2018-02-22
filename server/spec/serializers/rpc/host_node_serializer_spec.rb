describe Rpc::HostNodeSerializer do
  let(:now) { Time.new(2017, 03, 27, 11, 21, 55, '+03:00') }
  let(:grid) { Grid.create!(name: 'test-grid') }

  subject { described_class.new(host_node) }

  context "for a minimal host node" do
    let(:host_node) {
      grid.create_node!('test-node',
        created_at: now,
        updated_at: now,
        node_id: 'wxyz',
      )
    }

    it "serializs all fields" do
      expect(subject.to_hash).to match(
        id: 'wxyz',
        created_at: "2017-03-27 08:21:55 UTC",
        updated_at: "2017-03-27 08:21:55 UTC",
        name: 'test-node',
        labels: [],
        overlay_ip: "10.81.0.1",
        peer_ips: [],
        node_number: 1,
        initial_member: true,
        grid: a_hash_including(
          id: 'test-grid',
        ),
      )
    end
  end
end
