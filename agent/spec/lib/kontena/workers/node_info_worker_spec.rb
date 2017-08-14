describe Kontena::Workers::NodeInfoWorker, celluloid: true do
  include RpcClientMocks

  let(:node_id) { 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS' }
  let(:subject) { described_class.new(node_id, false) }
  let(:node) do
    Node.new(
      'id' => node_id,
      'instance_number' => 1,
      'grid' => {

      }
    )
  end
  let(:docker_info) { {
    'Name' => 'node-1',
    'Labels' => nil,
    'ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS',
    'Plugins' => {
      'Network' => ['bridge', 'host'],
      'Volume' => ['local']
    },
  }}

  before(:each) do
    mock_rpc_client
    allow(Docker).to receive(:info).and_return(docker_info)
    allow(subject.wrapped_object).to receive(:plugins).and_return([
      { 'Name' => 'foo:latest', 'Enabled' => true, 'Config' => { 'Interface' => { 'Types' => ['docker.volumedriver/1.0']} } }
    ])
    allow(Net::HTTP).to receive(:get).and_return('8.8.8.8')
    allow(rpc_client).to receive(:request)
    allow(rpc_client).to receive(:notification)
  end

  describe '#initialize' do
    it 'subscribes to websocket:connected channel' do
      expect(subject.wrapped_object).to receive(:publish_node_info).once
      Celluloid::Notifications.publish('websocket:connected', {})
      sleep 0.01
    end
  end

  describe '#start' do
    before(:each) { allow(rpc_client).to receive(:request) }

    it 'calls #publish_node_info' do
      stub_const('Kontena::Workers::NodeInfoWorker::PUBLISH_INTERVAL', 0.01)
      allow(subject.wrapped_object).to receive(:fetch_node).and_return(node)
      expect(subject.wrapped_object).to receive(:publish_node_info).at_least(:once)
      subject.async.start
      sleep 0.1
      subject.terminate
    end
  end

  describe '#publish_node_info' do
    before(:each) do
      allow(subject.wrapped_object).to receive(:interface_ip).with('eth1').and_return('192.168.66.2')
    end

    it 'sends node info via rpc' do
      expect(rpc_client).to receive(:request).once
      subject.publish_node_info
    end

    it 'contains docker id' do
      expect(rpc_client).to receive(:request).once.with(
        '/nodes/update', [node_id, hash_including('ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS')]
      )
      subject.publish_node_info
    end

    it 'contains public ip' do
      expect(rpc_client).to receive(:request).once.with(
        '/nodes/update', [node_id, hash_including('PublicIp' => '8.8.8.8')]
      )
      subject.publish_node_info
    end

    it 'contains private ip' do
      expect(rpc_client).to receive(:request).once.with(
        '/nodes/update', [node_id, hash_including('PrivateIp' => '192.168.66.2')]
      )
      subject.publish_node_info
    end

    it 'contains agent_version' do
      expect(rpc_client).to receive(:request).once do |key, msg|
        expect(msg['AgentVersion']).to match(/\d+\.\d+\.\d+/)
      end
      subject.publish_node_info
    end
  end

  describe '#network_drivers' do
    it 'returns array of drivers' do
      expect(subject.network_drivers(docker_info)).to match [
        {name: 'bridge'},
        {name: 'host'},
      ]
    end
  end

  describe '#volume_drivers' do
    it 'returns array of drivers' do
      expect(subject.volume_drivers(docker_info)).to match [
        {name: 'foo', version: 'latest'},
        {name: 'local'},
      ]
    end
  end

  describe '#public_ip' do
    it 'returns ip from env if set' do
      allow(ENV).to receive(:[]).with('KONTENA_PUBLIC_IP').and_return('128.105.39.11')
      expect(subject.public_ip).to eq('128.105.39.11')
    end

    it 'returns ip from akamai by default' do
      expect(subject.public_ip).to eq('8.8.8.8')
    end
  end

  describe '#private_ip' do
    it 'returns ip from env if set' do
      allow(ENV).to receive(:[]).with('KONTENA_PRIVATE_IP').and_return('192.168.2.10')
      expect(subject.private_ip).to eq('192.168.2.10')
    end

    it 'returns ip from private interface by default' do
      allow(subject.wrapped_object).to receive(:interface_ip).and_return('192.168.2.10')
      expect(subject.private_ip).to eq('192.168.2.10')
    end
  end
end
