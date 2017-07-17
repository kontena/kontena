describe Rpc::NodeHandler do
  let(:grid) { Grid.create! }
  let(:subject) { described_class.new(grid) }
  let(:node) do
    HostNode.create!(
      node_id: 'a', grid: grid, name: 'test-node', labels: ['region=ams2'],
    )
  end

  describe '#get' do
    it 'fails if the node_id is not found' do
      expect{subject.get('b')}.to raise_error 'Missing HostNode: b'
    end

    it 'returns correct peer ips' do
      HostNode.create!(
        node_id: 'b', grid: grid, name: 'test-node-2', labels: ['region=ams2'],
        private_ip: '10.12.1.3', public_ip: '80.240.128.4'
      )
      HostNode.create!(
        node_id: 'c', grid: grid, name: 'test-node-3', labels: ['region=ams3'],
        private_ip: '10.23.1.4', public_ip: '146.185.176.0'
      )
      json = subject.get(node.node_id)
      expect(json[:peer_ips]).to include('10.12.1.3')
      expect(json[:peer_ips]).to include('146.185.176.0')
    end
  end

  describe '#update' do
    it 'fails if the node_id is wrong' do
      expect{subject.update('b', {'ID' => 'b'})}.to raise_error 'Missing HostNode: b'
    end

    it 'calls attributes_from_docker and sets updated, changing the node status to online' do
      expect_any_instance_of(HostNode).to receive(:attributes_from_docker).with(hash_including('AgentVersion' => '1.4.0.dev')).and_call_original

      expect{
        subject.update('a', {'ID' => 'a', 'AgentVersion' => '1.4.0.dev'})
      }.to change{node.reload.updated_at}

      expect(node.agent_version).to eq '1.4.0.dev'
    end
  end

  describe '#stats' do
    it 'saves host_node_stat item' do
      node

      expect {
        subject.stats(node.node_id, {
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

      subject.stats(node.node_id, {
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

      subject.stats(node.node_id, {
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
