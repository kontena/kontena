
describe HostNodes::Update, celluloid: true do
  let(:grid) { Grid.create!(name: 'test') }
  let(:node) { HostNode.create!(name: 'node-1', grid: grid, node_id: 'AA') }

  describe '#run' do
    it 'updates node labels' do
      node.labels = []
      labels = ['foo=bar', 'bar=baz']
      expect {
        described_class.new(
          host_node: node,
          labels: labels
        ).run
      }.to change{ node.labels }.from([]).to(labels)
    end

    it 'notifies grid nodes' do
      mutation = described_class.new(
        host_node: node,
        labels: []
      )
      expect(mutation).to receive(:notify_grid).once.with(grid)
      mutation.run
    end
  end
end
