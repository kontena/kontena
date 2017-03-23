
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
  end
end
