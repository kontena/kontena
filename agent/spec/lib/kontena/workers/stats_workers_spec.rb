require_relative '../../helpers/fixtures_helpers'

describe Kontena::Workers::StatsWorker, :celluloid => true do
  include FixturesHelpers
  include RpcClientMocks

  let(:subject) { described_class.new(false) }
  let(:container) { spy(:container, id: 'foo', labels: {}) }
  let(:node) do
    Node.new(
      'id' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS',
      'instance_number' => 1,
      'grid' => {}
    )
  end

  before(:each) do
    mock_rpc_client
  end

  describe '#publish_stats' do
    before do
      allow(subject.wrapped_object).to receive(:cadvisor_running?).and_return(true)
    end

    it 'loops through all containers' do
      expect(subject.wrapped_object).to receive(:get).once.with('/api/v1.2/subcontainers').and_return([
        { namespace: 'docker', id: 'id', name: '/docker/id' },
      ])
      expect(subject.wrapped_object).to receive(:send_container_stats).once { |args| expect(args[:id]).to eq 'id' }
      subject.publish_stats
    end

    it 'ignores systemd mount cgroups' do
      expect(subject.wrapped_object).to receive(:get).once.with('/api/v1.2/subcontainers').and_return([
        { namespace: 'docker', id: 'id1', name: '/docker/id' },
        { namespace: 'docker', id: 'id2', name: '/system.slice/var-lib-docker-containers-id-shm.mount' },
      ])
      expect(subject.wrapped_object).to receive(:send_container_stats).once { |args| expect(args[:id]).to eq 'id1' }
      subject.publish_stats
    end

    it 'does nothing on get error' do
      expect(subject.wrapped_object).to receive(:get).once.with('/api/v1.2/subcontainers').and_return(nil)
      expect(subject.wrapped_object).not_to receive(:send_container_stats)
      subject.publish_stats
    end

    it 'does not call send_stats if no container stats found' do
      expect(subject.wrapped_object).to receive(:get).once.with('/api/v1.2/subcontainers').and_return({})
      expect(subject.wrapped_object).not_to receive(:send_container_stats)
      subject.publish_stats
    end
  end

  describe '#get' do
    it 'gets cadvisor stats for given container' do
      excon = double
      response = double
      allow(subject.wrapped_object).to receive(:client).and_return(excon)
      expect(excon).to receive(:get).with(:path => '/api/v1.2/foo').and_return(response)
      allow(response).to receive(:status).and_return(200)
      allow(response).to receive(:body).and_return('{"foo":"bar"}')
      expect(subject.get('/api/v1.2/foo')).to eq({:foo => "bar"})
    end

    it 'retries 3 times' do
      excon = double
      allow(subject.wrapped_object).to receive(:client).and_return(excon)
      allow(excon).to receive(:get).with(:path => '/api/v1.2/foo').and_raise(Excon::Errors::Error)
      expect(excon).to receive(:get).exactly(3).times
      subject.get('/api/v1.2/foo')
    end


    it 'return nil on 500 status' do
      excon = double
      response = double
      allow(subject.wrapped_object).to receive(:client).and_return(excon)
      allow(excon).to receive(:get).with(:path => '/api/v1.2/foo').and_return(response)
      allow(response).to receive(:status).and_return(500)
      allow(response).to receive(:body).and_return('{"foo":"bar"}')
      expect(subject.get('/api/v1.2/foo')).to eq(nil)
    end

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
      expect(subject.statsd).to be_nil
      subject.configure_statsd(node)
      expect(subject.statsd).not_to be_nil
    end

    it 'does not initialize statsd if no statsd config exists' do
      node = Node.new(
        'grid' => {
          'stats' => {}
        }
      )
      expect(subject.statsd).to be_nil
      subject.configure_statsd(node)
      expect(subject.statsd).to be_nil
    end

    it 'does not crash the worker if statsd config fails' do
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
      expect(Statsd).to receive(:new).and_raise("Boom")
      subject.configure_statsd(node)
      expect(subject.statsd).to be_nil
    end
  end

  describe '#send_statsd_metrics' do
    let(:event) do
      {
        id: 'aaaaaa',
        spec: {
          labels: {
            :'io.kontena.service.name' => 'foobar'
          }
        },
        cpu: {
          usage_pct: 12.32
        },
        memory: {
          usage: 24 * 1024 * 1024
        },
        filesystem: [],
        diskio: [],
        network: []
      }
    end

    let(:statsd) do
      instance_double(Statsd)
    end

    it 'sends statsd metrics' do
      allow(subject.wrapped_object).to receive(:statsd).and_return(statsd)
      expect(statsd).to receive(:gauge).with('services.foobar.cpu.usage', 12.32)
      expect(statsd).to receive(:gauge).with('services.foobar.memory.usage', 24 * 1024 * 1024)
      subject.send_statsd_metrics('foobar', event)
    end
  end

  describe '#send_container_stats' do
    let(:event) do
      JSON.parse(fixture('container_stats.json'), symbolize_names: true)
    end

    it 'sends container stats' do
      expect(subject.wrapped_object).to receive(:send_statsd_metrics).with('weave', hash_including({
          id: 'a675a5cd5f36ba747c9495f3dbe0de1d5f388a2ecd2aaf5feb00794e22de6c5e',
          spec: 'spec',
          cpu: {
            usage: 100000000,
            usage_pct: 0.28
          },
          memory: {
            usage: 1024,
            working_set: 2048
          },
          filesystem: event.dig(:stats, -1, :filesystem),
          diskio: event.dig(:stats, -1, :diskio),
          network: {
            internal: {
              interfaces: [],
              rx_bytes: 0,
              rx_bytes_per_second: 0,
              tx_bytes: 0,
              tx_bytes_per_second: 0
            },
            external: {
              interfaces: [],
              rx_bytes: 0,
              rx_bytes_per_second: 0,
              tx_bytes: 0,
              tx_bytes_per_second: 0
            }
          }
        }
      ))
      expect(rpc_client).to receive(:notification).with(
        '/containers/stat', [hash_including(id: 'a675a5cd5f36ba747c9495f3dbe0de1d5f388a2ecd2aaf5feb00794e22de6c5e')]
      )
      subject.send_container_stats(event)
    end

    it 'does not fail on missing cpu stats' do
      event[:stats][-1][:cpu][:usage][:per_cpu_usage] = nil
      expect(subject.wrapped_object).to receive(:send_statsd_metrics).with('weave', hash_including({
          id: 'a675a5cd5f36ba747c9495f3dbe0de1d5f388a2ecd2aaf5feb00794e22de6c5e',
          spec: 'spec',
          cpu: {
            usage: 100000000,
            usage_pct: 0.28
          },
          memory: {
            usage: 1024,
            working_set: 2048
          },
          filesystem: event.dig(:stats, -1, :filesystem),
          diskio: event.dig(:stats, -1, :diskio),
          network: {
            internal: {
              interfaces: [],
              rx_bytes: 0,
              rx_bytes_per_second: 0,
              tx_bytes: 0,
              tx_bytes_per_second: 0
            },
            external: {
              interfaces: [],
              rx_bytes: 0,
              rx_bytes_per_second: 0,
              tx_bytes: 0,
              tx_bytes_per_second: 0
            }
          }
        }
      ))
      expect(rpc_client).to receive(:notification).with(
        '/containers/stat', [hash_including(id: 'a675a5cd5f36ba747c9495f3dbe0de1d5f388a2ecd2aaf5feb00794e22de6c5e')]
      )
      subject.send_container_stats(event)
    end
  end

  describe '#send_container_stats' do
    it 'sends stats via rpc' do
      expect(rpc_client).to receive(:notification).once.with('/containers/stat', [hash_including(time: String)])

      container = {
        aliases: [],
        stats: [
          {
            timestamp: "2017-03-01 00:00:00",
            cpu: {
              usage: {
                total: 1
              }
            }
          },
          {
            timestamp: "2017-03-01 00:00:01",
            cpu: {
              usage: {
                total: 1
              }
            }
          }
        ]
      }
      subject.send_container_stats(container)
    end
  end
end
