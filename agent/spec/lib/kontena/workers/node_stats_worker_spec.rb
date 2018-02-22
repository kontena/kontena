describe Kontena::Workers::NodeStatsWorker, celluloid: true do
  include RpcClientMocks

  let(:node_id) { 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS' }
  let(:subject) { described_class.new(false) }

  let(:node) { instance_double(Node, id: node_id,
    grid: { 'name' => 'test' },
    statsd_conf: {},
  ) }
  let(:statsd_node) { instance_double(Node, id: node_id,
    grid: { 'name' => 'test' },
    statsd_conf: {
      'server' => '192.168.24.33',
      'port' => 8125,
    },
  ) }
  let(:statsd2_node) { instance_double(Node, id: node_id,
    grid: { 'name' => 'test' },
    statsd_conf: {
      'server' => '192.168.24.34',
      'port' => 8125,
    },
  ) }
  let(:statsd) { instance_double(Statsd) }
  let(:statsd2) { instance_double(Statsd) }

  let(:stats) { double() }

  before(:each) do
    mock_rpc_client
  end

  describe '#start' do
    it 'calls publish_node_stats on every, configure on observe' do
      allow(subject.wrapped_object).to receive(:every) do |&block|
        expect(subject.wrapped_object).to receive(:publish_node_stats)
        block.call
      end

      allow(subject.wrapped_object).to receive(:observe) do |actor, &block|
        expect(subject.wrapped_object).to receive(:configure).with(node)
        block.call(node)
      end
    end
  end

  context 'without a configured node' do
    describe '#configure' do
      it 'configures the node without statsd' do
        expect(subject.wrapped_object).to receive(:configure_statsd).with(node)

        subject.configure(node)

        expect(subject.node).to eq node
        expect(subject.statsd).to be nil
      end

      it 'configures the node with statsd' do
        expect(subject.wrapped_object).to receive(:configure_statsd).with(statsd_node).and_return(statsd)

        subject.configure(statsd_node)

        expect(subject.node).to eq statsd_node
        expect(subject.statsd).to eq statsd
      end
    end

    describe '#publish_node_stats' do
      before do
        allow(subject.wrapped_object).to receive(:collect_node_stats).and_return(:stats)
      end

      it 'does not send any stats' do
        expect(subject.wrapped_object).to_not receive(:send_node_stats)
        expect(subject.wrapped_object).to_not receive(:send_statsd_metrics)

        subject.publish_node_stats
      end
    end
  end

  describe '#configure_statsd' do
    it 'initializes statsd client with node statsd config' do
      expect(statsd).to receive(:namespace=).with('test')
      expect(Statsd).to receive(:new).with('192.168.24.33', 8125).and_return(statsd)

      expect(subject.configure_statsd(statsd_node)).to eq statsd
    end

    it 'does not initialize statsd if no statsd configured' do
      expect(Statsd).to_not receive(:new)

      expect(subject.configure_statsd(node)).to be nil
    end
  end

  context 'with a configured node without statsd' do
    before do
      allow(subject.wrapped_object).to receive(:configure_statsd).with(node).and_return(nil)

      subject.configure node
    end

    describe '#configure' do
      it 'reconfigures the node with statsd' do
        expect(subject.wrapped_object).to receive(:configure_statsd).with(statsd_node).and_return(statsd)

        subject.configure(statsd_node)

        expect(subject.node).to eq statsd_node
        expect(subject.statsd).to eq statsd
      end
    end

    describe '#publish_node_stats' do
      before do
        allow(subject.wrapped_object).to receive(:collect_node_stats).and_return(:stats)
      end

      it 'sends rpc stats' do
        expect(subject.wrapped_object).to receive(:send_node_stats)
        expect(subject.wrapped_object).to_not receive(:send_statsd_metrics)

        subject.publish_node_stats
      end
    end

    describe '#send_node_stats' do
      it 'sends stats via rpc' do
        expect(rpc_client).to receive(:notification).once.with('/nodes/stats', [node.id, stats])

        subject.send_node_stats(stats)
      end
    end
  end

  context 'with a configured node with statsd' do
    before do
      expect(subject.wrapped_object).to receive(:configure_statsd).with(statsd_node).and_return(statsd)

      subject.configure statsd_node
    end

    describe '#configure' do
      it 'does not reconfigure statsd if the config is the same' do
        expect(subject.wrapped_object).to_not receive(:configure_statsd)

        subject.configure(statsd_node)

        expect(subject.node).to eq statsd_node
        expect(subject.statsd).to eq statsd
      end

      it 'reconfigure statsd if the config changes' do
        expect(subject.wrapped_object).to receive(:configure_statsd).with(statsd2_node).and_return(statsd2)

        subject.configure(statsd2_node)

        expect(subject.node).to eq statsd2_node
        expect(subject.statsd).to eq statsd2
      end
    end

    describe '#publish_node_stats' do
      before do
        allow(subject.wrapped_object).to receive(:collect_node_stats).and_return(:stats)
      end

      it 'sends rpc and statsd stats' do
        expect(subject.wrapped_object).to receive(:send_node_stats)
        expect(subject.wrapped_object).to receive(:send_statsd_metrics)

        subject.publish_node_stats
      end
    end

    describe '#send_statsd_metrics' do
      let(:stats) { spy() } # used for recursive lookups

      before do
        allow(subject.wrapped_object).to receive(:docker_info).and_return({
          'Name' => 'test,'
        })
      end

      it 'sends stats to statsd' do
        # Will be called 15 times if there are no file systems
        expect(statsd).to receive(:gauge).at_least(15).times

        subject.send_statsd_metrics(stats)
      end
    end
  end

  describe '#collect_node_stats' do
    before do
      allow(Docker).to receive(:info).and_return({
        'Name' => 'node-1',
        'Labels' => nil,
        'ID' => node_id,
        'Plugins' => {
          'Network' => ['bridge', 'host'],
          'Volume' => ['local']
        }
      })
      allow(subject.wrapped_object).to receive(:calculate_containers_time).and_return(100)
    end

    it 'returns hash of stats' do
      expect(subject.collect_node_stats).to match hash_including(
        memory: Hash,
        usage: Hash,
        load: Hash,
        filesystem: Array,
        cpu: Hash,
        network: Hash,
        time: String,
      )
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
