
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
    allow(subject.wrapped_object).to receive(:calculate_containers_time).and_return(100)
    allow(rpc_client).to receive(:notification)
  }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'subscribes to websocket:connected channel' do
      expect(subject.wrapped_object).to receive(:publish_node_info).once
      Celluloid::Notifications.publish('websocket:connected', {})
      sleep 0.01
    end
  end

  describe '#start' do
    before(:each) { allow(rpc_client).to receive(:notification) }

    it 'calls #publish_node_info' do
      stub_const('Kontena::Workers::NodeInfoWorker::PUBLISH_INTERVAL', 0.01)
      allow(subject.wrapped_object).to receive(:fetch_node).and_return(node)
      expect(subject.wrapped_object).to receive(:publish_node_info).at_least(:once)
      subject.async.start
      sleep 0.1
      subject.terminate
    end

    it 'calls #publish_node_info' do
      stub_const('Kontena::Workers::NodeInfoWorker::PUBLISH_INTERVAL', 0.01)
      allow(subject.wrapped_object).to receive(:fetch_node).and_return(node)
      expect(subject.wrapped_object).to receive(:publish_node_stats).at_least(:once)
      subject.async.start
      sleep 0.1
      subject.terminate
    end
  end

  describe '#on_node_info' do
    it 'initializes statsd client if node has statsd config' do
      node = Node.new(
        'grid' => {
          'stats' => {
            'statsd' => {
              'server' => '192.168.24.33',
              'port' => 8125
            }
          }
        }
      )
      expect(subject.statsd).to be_nil
      subject.on_node_info('agent:on_node_info', node)
      expect(subject.statsd).not_to be_nil
    end

    it 'does not initialize statsd if no statsd config exists' do
      node = Node.new(
        'grid' => {
          'stats' => {}
        }
      )
      expect(subject.statsd).to be_nil
      subject.on_node_info('agent:on_node_info', node)
      expect(subject.statsd).to be_nil
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

  describe '#publish_node_stats' do
    it 'sends node stats via rpc' do
      expect(rpc_client).to receive(:notification).once.with(
        '/nodes/stats', [hash_including(id: 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS')]
      )
      subject.publish_node_stats
    end
  end

  describe '#calculate_container_time' do
    context 'container is running' do
      it 'calculates container time since last check' do
        allow(subject.wrapped_object).to receive(:stats_since).and_return(Time.now - 30)
        container = double(:container, state: {
          'StartedAt' => (Time.now - 300).to_s,
          'Running' => true
        })
        time = subject.calculate_container_time(container)
        expect(time).to eq(30)
      end

      it 'calculates container time since container is started' do
        allow(subject.wrapped_object).to receive(:stats_since).and_return(Time.now - 60)
        container = double(:container, state: {
          'StartedAt' => (Time.now - 50).to_s,
          'Running' => true
        })
        time = subject.calculate_container_time(container)
        expect(time).to eq(50)
      end
    end

    context 'container is not running' do
      it 'calculates partial container time since last check' do
        allow(subject.wrapped_object).to receive(:stats_since).and_return(Time.now - 60)
        container = double(:container, state: {
          'StartedAt' => (Time.now - 300).to_s,
          'FinishedAt' => (Time.now - 2).to_s,
          'Running' => false
        })
        time = subject.calculate_container_time(container)
        expect(time).to eq(58)
      end

      it 'calculates partial container time since container is started' do
        allow(subject.wrapped_object).to receive(:stats_since).and_return(Time.now - 60)
        container = double(:container, state: {
          'StartedAt' => (Time.now - 50).to_s,
          'FinishedAt' => (Time.now - 2).to_s,
          'Running' => false
        })
        time = subject.calculate_container_time(container)
        expect(time).to eq(48)
      end
    end
  end

  describe '#on_container_event' do
    context 'die' do
      it 'calculates container time if container is found' do
        event = double(:event, status: 'die', id: 'aaa')
        container = double(:container, id: 'aaa')
        allow(Docker::Container).to receive(:get).and_return(container)
        expect(subject.wrapped_object).to receive(:calculate_container_time).and_return(1)
        subject.on_container_event('on_container_event', event)
      end

      it 'does not calculate container time if container does not exist' do
        event = double(:event, status: 'die', id: 'aaa')
        allow(Docker::Container).to receive(:get).and_return(nil)
        expect(subject.wrapped_object).not_to receive(:calculate_container_time)
        subject.on_container_event('on_container_event', event)
      end
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

  describe '#publish_node_stats' do
    it 'sends stats via rpc with timestamps' do
      expect(rpc_client).to receive(:notification).once.with('/nodes/stats', [hash_including(time: String)])
      subject.publish_node_stats
    end
  end
end
