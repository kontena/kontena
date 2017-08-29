describe HostNodes::Common do
  let(:described_class) {
    Class.new do
      include HostNodes::Common
    end
  }

  context 'for a grid with three nodes' do
    let!(:grid) { Grid.create!(name: 'test') }
    let!(:node_a) { grid.create_node!('node-a', node_id: 'AA', connected: true) }
    let!(:node_b) { grid.create_node!('node-b', node_id: 'BB', connected: true) }
    let!(:node_c) { grid.create_node!('node-c', node_id: 'CC', connected: false) }

    describe '#notify_grid' do
      let(:node1_plugger) { instance_double(Agent::NodePlugger) }
      let(:node2_plugger) { instance_double(Agent::NodePlugger) }
      let(:node3_plugger) { instance_double(Agent::NodePlugger) }

      before do
        allow(Agent::NodePlugger).to receive(:new).with(node_a).and_return(node1_plugger)
        allow(Agent::NodePlugger).to receive(:new).with(node_b).and_return(node2_plugger)
        allow(Agent::NodePlugger).to receive(:new).with(node_c).and_return(node3_plugger)
      end

      it 'notifies all connected nodes' do
        expect(node1_plugger).to receive(:send_node_info)
        expect(node2_plugger).to receive(:send_node_info)
        expect(node3_plugger).to_not receive(:send_node_info)
        subject.notify_grid(grid)
      end
    end
  end
end
