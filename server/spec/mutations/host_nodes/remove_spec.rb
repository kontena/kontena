require_relative '../../spec_helper'

describe HostNodes::Remove do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:grid) { Grid.create!(name: 'test') }
  let(:node_a) { HostNode.create!(name: 'node-a', grid: grid, node_id: 'AA') }
  let(:node_b) { HostNode.create!(name: 'node-b', grid: grid, node_id: 'BB') }

  describe '#run' do
    it 'removes node' do
      node_a; node_b
      expect {
        described_class.new(
          host_node: node_a,
        ).run
      }.to change{ grid.host_nodes.count }.by(-1)
    end

    it 'notifies grid nodes' do
      mutation = described_class.new(
        host_node: node_a,
      )
      expect(mutation).to receive(:notify_grid).once.with(grid)
      mutation.run
    end
  end
end
