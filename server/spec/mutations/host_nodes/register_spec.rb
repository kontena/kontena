require_relative '../../spec_helper'

describe HostNodes::Register do
  let(:grid) { Grid.create!(name: 'test') }

  describe '#run' do
    it 'registers new node to grid' do
      expect {
        described_class.new(
          grid: grid,
          id: 'aaa',
          private_ip: '192.168.100.2'
        ).run
      }.to change{ grid.host_nodes.count }.by(1)
    end

    it 'updates existing node' do
      node = grid.host_nodes.create!(node_id: 'aaa')
      expect {
        described_class.new(
          grid: grid,
          id: node.node_id,
          private_ip: '192.168.100.2'
        ).run
      }.to change{ grid.host_nodes.count }.by(0)
      node.reload
      expect(node.private_ip).to eq('192.168.100.2')
    end

    it 'generates discovery url for the grid if it does not exist' do
      node1 = grid.host_nodes.create!(node_id: 'aaa')
      node2 = grid.host_nodes.create!(node_id: 'bbb')
      expect {
        subject = described_class.new(
          grid: grid,
          id: node1.node_id,
          private_ip: '192.168.100.2'
        )
        expect(subject).to receive(:discovery_url).with(2).once.and_return('https://discovery.etcd.io/foo')
        subject.run
      }.to change{ grid.host_nodes.count }.by(0)
      grid.reload
      expect(grid.discovery_url).not_to eq(nil)
    end
  end
end
