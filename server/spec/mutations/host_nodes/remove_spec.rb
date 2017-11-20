describe HostNodes::Remove do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node) { grid.create_node!('test-node', node_id: 'AAAA', connected: true) }

  describe '#run' do
    let(:subject) { described_class.new(host_node: node) }

    before do
      node
    end

    it 'removes the node' do
      expect {
        subject.run!
      }.to change{grid.reload.host_nodes.count}.from(1).to(0)
    end

    context 'with a second node in the same grid' do
      let(:other_node) { grid.create_node!('other-node', node_id: 'BBBB', connected: true) }
      let(:rpc_client) { instance_double(RpcClient) }

      before do
        other_node
        allow(RpcClient).to receive(:new).with(other_node.node_id, Integer).and_return(rpc_client)
      end

      it 'notifies connected grid nodes' do
        expect(rpc_client).to receive(:notify).with('/agent/node_info', hash_including(
          peer_ips: [],
        ))

        subject.run!
      end
    end
  end
end
