
describe Kontena::Workers::NodeInfoWorker do
  include RpcClientMocks

  let(:subject) { described_class.new(false) }
  let(:node) do
    Node.new(
      'id' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS',
      'instance_number' => 1,
      'grid' => {

      }
    )
  end

  before(:each) {
    Celluloid.boot
    mock_rpc_client
    allow(Docker).to receive(:info).and_return({
      'Name' => 'node-1',
      'Labels' => nil,
      'ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS'
    })
    allow(Net::HTTP).to receive(:get).and_return('8.8.8.8')
  }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'subscribes to websocket:connected channel' do
      expect(subject.wrapped_object).to receive(:publish_node_info).once.and_call_original
      Celluloid::Notifications.publish('websocket:connected', {})
      Kontena::Helpers::WaitHelper.wait_until!(interval: 0.1, timeout: 1.0) { subject.node }
    end
  end

  describe '#start' do
    before(:each) { allow(rpc_client).to receive(:notification) }

    it 'calls #publish_node_info' do
      expect(subject.wrapped_object).to receive(:every).with(Kontena::Workers::NodeInfoWorker::PUBLISH_INTERVAL) {|&block| block.call}
      expect(subject.wrapped_object).to receive(:publish_node_info)
      subject.start
    end
  end

  describe '#publish_node_info' do
    before(:each) do
      allow(subject.wrapped_object).to receive(:interface_ip).with('eth1').and_return('192.168.66.2')
    end

    it 'sends node info via rpc' do
      expect(rpc_client).to receive(:notification).once
      subject.publish_node_info
    end

    it 'contains docker id' do
      expect(rpc_client).to receive(:notification).once.with(
        '/nodes/update', [hash_including('ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS')]
      )
      subject.publish_node_info
    end

    it 'contains public ip' do
      expect(rpc_client).to receive(:notification).once.with(
        '/nodes/update', [hash_including('PublicIp' => '8.8.8.8')]
      )
      subject.publish_node_info
    end

    it 'contains private ip' do
      expect(rpc_client).to receive(:notification).once.with(
        '/nodes/update', [hash_including('PrivateIp' => '192.168.66.2')]
      )
      subject.publish_node_info
    end

    it 'contains agent_version' do
      expect(rpc_client).to receive(:notification).once do |key, msg|
        expect(msg['AgentVersion']).to match(/\d+\.\d+\.\d+/)
      end
      subject.publish_node_info
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
