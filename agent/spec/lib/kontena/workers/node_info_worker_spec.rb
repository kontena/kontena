describe Kontena::Workers::NodeInfoWorker do
  include RpcClientMocks

  let(:subject) { described_class.new(false) }
  let(:statsd) { double(:statsd) }
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
      'ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS',
      'Plugins' => {
        'Network' => ['bridge', 'host'],
        'Volume' => ['local']
      }
    })
    allow(subject.wrapped_object).to receive(:plugins).and_return([
      { 'Name' => 'foo:latest', 'Enabled' => true, 'Config' => { 'Interface' => { 'Types' => ['docker.volumedriver/1.0']} } }
    ])
    allow(Net::HTTP).to receive(:get).and_return('8.8.8.8')
    allow(subject.wrapped_object).to receive(:calculate_containers_time).and_return(100)
    allow(rpc_client).to receive(:request)
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
    before(:each) { allow(rpc_client).to receive(:request) }

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
      expect(rpc_client).to receive(:request).once
      subject.publish_node_info
    end

    it 'contains docker id' do
      expect(rpc_client).to receive(:request).once.with(
        '/nodes/update', [hash_including('ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS')]
      )
      subject.publish_node_info
    end

    it 'contains public ip' do
      expect(rpc_client).to receive(:request).once.with(
        '/nodes/update', [hash_including('PublicIp' => '8.8.8.8')]
      )
      subject.publish_node_info
    end

    it 'contains private ip' do
      expect(rpc_client).to receive(:request).once.with(
        '/nodes/update', [hash_including('PrivateIp' => '192.168.66.2')]
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
      expect(subject.network_drivers).to include(hash_including({name: 'bridge'}))
    end
  end

  describe '#volume_drivers' do
    it 'returns array of drivers' do
      expect(subject.volume_drivers).to include(hash_including({name: 'local'}))
      expect(subject.volume_drivers).to include(hash_including({name: 'foo', version: 'latest'}))
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

    before(:each) do
      allow(rpc_client).to receive(:notification)
    end

    it 'sends stats via rpc' do
      expect(rpc_client).to receive(:notification).once.with('/nodes/stats',
        [hash_including(id: String, memory: Hash, usage: Hash, load: Hash,
                        filesystem: Array, cpu: Hash, network: Hash, time: String)])
      subject.publish_node_stats
    end

    it 'sends stats to statsd' do
      subject.instance_variable_set("@statsd", statsd)

      # Will be called 18 times if there is one file system
      expect(statsd).to receive(:gauge).at_least(18).times
      subject.publish_node_stats
    end
  end

  describe '#calculate_cpu_usage' do
    it 'calculates cpu usage' do
      prev = [
        # cpu-num, user ticks, system ticks, nice ticks, idle ticks
        Vmstat::Cpu.new(0, 926444, 1715744, 0, 8413871),
        Vmstat::Cpu.new(1, 67122, 93965, 0, 10891139)
      ]
      cur = [
        Vmstat::Cpu.new(0, 926482, 1715820, 0, 8414258),
        Vmstat::Cpu.new(1, 67123, 93967, 0, 10891637)
      ]

      result = subject.calculate_cpu_usage(prev, cur)

      expect(result).to eq({
        num_cores: 2,
        system: 15.568862275449103,
        user: 7.784431137724551,
        nice: 0,
        idle: 176.64670658682633
      })
    end
  end

  describe '#calculate_network_traffic' do
    it 'calculates network traffic' do
      num_seconds = 60.0

      prev = [
        #  name=nil, in_bytes=nil, in_errors=nil, in_drops=nil, out_bytes=nil, out_errors=nil, type=nil
        Vmstat::NetworkInterface.new("weave", 50, 51, 52, 70, 71, 0),
        Vmstat::NetworkInterface.new("vethwe123", 100, 101, 102, 110, 111, 0),
        Vmstat::NetworkInterface.new("docker0", 1000, 1001, 1002, 1010, 1011, 1),
        Vmstat::NetworkInterface.new("other", 9999, 9999, 9999, 9999, 9999, 1)
      ]
      cur = [
        Vmstat::NetworkInterface.new("weave", 70, 71, 72, 90, 91, 0),
        Vmstat::NetworkInterface.new("vethwe123", 200, 201, 202, 210, 211, 0),
        Vmstat::NetworkInterface.new("docker0", 2800, 2801, 2802, 3410, 3411, 1),
        Vmstat::NetworkInterface.new("other", 9999, 9999, 9999, 9999, 9999, 1)
      ]

      result = subject.calculate_network_traffic(prev, cur, num_seconds)

      expect(result).to eq({
          internal: {
            interfaces: ["weave", "vethwe123"],
            rx_bytes: 270,
            rx_bytes_per_second: 2, # ((200+70) - (50+100)) / 60
            tx_bytes: 300,
            tx_bytes_per_second: 2 # ((210+90) - (110+70)) / 60
          },
          external: {
            interfaces: ["docker0"],
            rx_bytes: 2800,
            rx_bytes_per_second: 30, # (2800 - 1000) / 60
            tx_bytes: 3410,
            tx_bytes_per_second: 40 # (3410 - 1010) / 60
          }
      })
    end
  end
end
