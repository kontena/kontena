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
          grid.create_node!("peer-node-#{i}",
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
end
