describe Kontena::Workers::NodeStatsWorker, celluloid: true do
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

  before(:each) do
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
    allow(subject.wrapped_object).to receive(:calculate_containers_time).and_return(100)
    allow(rpc_client).to receive(:request)
    allow(rpc_client).to receive(:notification)
    allow(rpc_client).to receive(:connected?).and_return(true)
  end

  describe '#configure_statsd' do
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
      expect {
        subject.configure_statsd(node)
      }.to change { subject.statsd }
    end

    it 'does not initialize statsd if no statsd config exists' do
      node = Node.new(
        'grid' => {
          'stats' => {}
        }
      )
      expect {
        subject.configure_statsd(node)
      }.not_to change { subject.statsd }
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
        Vmstat::Cpu.new(0, 100, 200, 300, 400),
        Vmstat::Cpu.new(1, 1000, 2000, 3000, 4000)
      ]
      cur = [
        Vmstat::Cpu.new(0, 125, 250, 375, 500),
        Vmstat::Cpu.new(1, 1250, 2500, 3750, 5000)
      ]

      #              CPU 0:            | CPU 1:
      # user:        125 - 100  =  25  | 1250 - 1000 =  250
      # system:      250 - 200  =  50  | 2500 - 2000 =  500
      # nice:        375 - 300  =  75  | 3750 - 3000 =  750
      # idle:        500 - 400  = 100  | 5000 - 4000 = 1000
      #              ----------------  | ------------------
      # total ticks:              250  |               2500
      #
      #
      # CPU 0 %:
      # user:   (25 / 250) * 100 = 10
      # system: (40 / 250) * 100 = 20
      # nice:   (55 / 250) * 100 = 30
      # idle:   (60 / 250) * 100 = 40
      #
      # CPU 1 %:
      # user:   (250 / 2500) * 100 = 10
      # system: (500 / 2500) * 100 = 20
      # nice:   (750 / 2500) * 100 = 30
      # idle:   (1000 / 2500) * 100 = 40

      result = subject.calculate_cpu_usage(prev, cur)

      expect(result).to eq({
        num_cores: 2,
        user: 20.0,
        system: 40.0,
        nice: 60.0,
        idle: 80.0
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
