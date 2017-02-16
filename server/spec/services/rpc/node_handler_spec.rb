require_relative '../../spec_helper'

describe Rpc::NodeHandler, celluloid: true do
  let(:grid) { Grid.create! }
  let(:subject) { described_class.new(grid) }
  let(:node) { HostNode.create!(grid: grid, name: 'test-node') }

  describe '#stats' do
    it 'saves host_node_stat item' do
      node
      expect {
        subject.stats({
          'node_id' => node.node_id,
          'load' => {'1m' => 0.1, '5m' => 0.2, '15m' => 0.1},
          'memory' => {},
          'filesystems' => [],
          'usage' => {
            'container_seconds' => 60*100
          }
        })
      }.to change{ node.host_node_stats.count }.by(1)
    end
  end
end
