
describe Rpc::NodeHandler, celluloid: true do
  let(:grid) { Grid.create! }
  let(:subject) { described_class.new(grid) }
  let(:node) { HostNode.create!(node_id: 'a', grid: grid, name: 'test-node') }

  describe '#stats' do
    it 'saves host_node_stat item' do
      node
      
      expect {
        subject.stats({
          'id' => node.node_id,
          'load' => {'1m' => 0.1, '5m' => 0.2, '15m' => 0.1},
          'memory' => {},
          'filesystems' => [],
          'usage' => {
            'container_seconds' => 60*100
          }
        })
      }.to change{ node.host_node_stats.count }.by(1)
    end

    it 'creates timestamps' do
      node

      subject.stats({
        'id' => node.node_id,
        'load' => {'1m' => 0.1, '5m' => 0.2, '15m' => 0.1},
        'memory' => {},
        'filesystems' => [],
        'usage' => {
          'container_seconds' => 60*100
        }
      })

      expect(node.host_node_stats[0].created_at).to be_a(Time)
    end

    it 'sets timestamps passed in' do
      node

      time = '2017-02-28 00:00:00 -0500'

      subject.stats({
        'id' => node.node_id,
        'load' => {'1m' => 0.1, '5m' => 0.2, '15m' => 0.1},
        'memory' => {},
        'filesystems' => [],
        'usage' => {
          'container_seconds' => 60*100
        },
        'time' => time
      })

      expect(node.host_node_stats[0].created_at).to eq Time.parse(time)
    end
  end
end
