
describe ContainerStat do
  it { should be_timestamped_document }
  it { should have_fields(:spec, :cpu, :memory, :filesystem, :diskio, :network)}

  it { should belong_to(:grid) }
  it { should belong_to(:grid_service) }
  it { should belong_to(:container) }
  it { should belong_to(:host_node) }

  it { should have_index_for(container_id: 1).with_options(background: true) }
  it { should have_index_for(grid_id: 1).with_options(background: true) }
  it { should have_index_for(grid_service_id: 1).with_options(background: true) }
  it { should have_index_for(created_at: 1).with_options(background: true) }

  describe '.latest' do
    let(:grid) { Grid.create!(name: 'test-grid') }
    let(:container) { Container.create!(grid: grid, name: 'test-1') }

    it 'returns latest stat item' do
      container.container_stats.create
      last = container.container_stats.create
      expect(described_class.latest).to eq(last)
    end

    it 'returns nil if no stats' do
      expect(described_class.latest).to be_nil
    end
  end

  describe 'methods' do
    let(:stat) { ContainerStat.new({
        spec: {
          "cpu" => { "mask" => "0-2" },
          "memory" => { "limit" => 1000 }
        },
        cpu: { "usage_pct" => 10.0 },
        memory: { "usage" => 100 },
        network: {
          "internal" => {
            "interfaces" => ["ethwe"],
            "rx_bytes" => 100.5,
            "tx_bytes" => 200.5,
            "rx_bytes_per_second" => 10,
            "tx_bytes_per_second" => 20
          }
        }
    })}

    describe '#calculate_num_cores' do
      it 'calculates correct number of cpu cores from cpu mask' do
        num_cores = ContainerStat.calculate_num_cores(stat.spec["cpu"]["mask"])
        expect(num_cores).to eq(3)
      end
    end
  end

  describe 'aggregations' do
    let(:grid_1) { Grid.create!(name: 'grid_1') }
    let(:grid_2) { Grid.create!(name: 'grid_2') }
    let(:grid_1_node_1) { grid_1.create_node!('grid_1_node_1') }
    let(:grid_1_node_2) { grid_1.create_node!('grid_1_node_2') }
    let(:grid_2_node_1) { grid_2.create_node!('grid_2_node_1') }
    let(:grid_1_service_1) { GridService.create!(grid: grid_1, name: 'grid_1_service_1', image_name: 'i1') }
    let(:grid_1_service_2) { GridService.create!(grid: grid_1, name: 'grid_1_service_2', image_name: 'i2') }
    let(:grid_2_service_1) { GridService.create!(grid: grid_2, name: 'grid_2_service_1', image_name: 'i1') }
    let(:grid_1_service_1_container_1) { Container.create!(grid: grid_1, host_node: grid_1_node_1, grid_service: grid_1_service_1, name: "grid_1_service_1_container_1") }
    let(:grid_1_service_1_container_2) { Container.create!(grid: grid_1, host_node: grid_1_node_2, grid_service: grid_1_service_1, name: "grid_1_service_1_container_2") }
    let(:grid_1_service_2_container_1) { Container.create!(grid: grid_1, host_node: grid_1_node_1, grid_service: grid_1_service_2, name: "grid_1_service_2_container_1") }
    let(:grid_2_service_1_container_1) { Container.create!(grid: grid_2, host_node: grid_2_node_1, grid_service: grid_2_service_1, name: "grid_2_service_1_container_1") }
    let(:stats) {
      ContainerStat.create!([
        # 1) Grid 1, Service 1, Container 1 - included in results (first)
        {
          grid: grid_1,
          grid_service: grid_1_service_1,
          container: grid_1_service_1_container_1,
          host_node: grid_1_service_1_container_1.host_node, # grid_1_node_1
          spec: {
            cpu: { mask: "0-1" },
            memory: { limit: 1000 }
          },
          cpu: { usage_pct: 10.0 },
          memory: { usage: 100 },
          network: {
            internal: {
              interfaces: ["ethwe"], rx_bytes: 100, tx_bytes: 200, rx_bytes_per_second: 100, tx_bytes_per_second: 200
            },
            external: {
              interfaces: ["eth0"], rx_bytes: 100.5, tx_bytes: 200.5, rx_bytes_per_second: 100.5, tx_bytes_per_second: 200.5
            }
          },
          created_at: Time.parse('2017-03-01 12:00:00 +00:00')
        },
        # 2) Grid 1, Service 1, Container 1 - included in results (first)
        {
          grid: grid_1,
          grid_service: grid_1_service_1,
          container: grid_1_service_1_container_1,
          host_node: grid_1_service_1_container_1.host_node, # grid_1_node_1
          spec: {
            cpu: { mask: "0-1" },
            memory: { limit: 1000 }
          },
          cpu: { usage_pct: 20.0 },
          memory: { usage: 200 },
          network: {
            internal: {
              interfaces: ["ethwe"], rx_bytes: 100, tx_bytes: 200, rx_bytes_per_second: 100, tx_bytes_per_second: 200
            },
            external: {
              interfaces: ["eth0"], rx_bytes: 100.5, tx_bytes: 200.5, rx_bytes_per_second: 100.5, tx_bytes_per_second: 200.5
            }
          },
          created_at: Time.parse('2017-03-01 12:00:30 +00:00')
        },
        # 3) Grid 1, Service 1, Container 2 - included in results (first)
        {
          grid: grid_1,
          grid_service: grid_1_service_1,
          container: grid_1_service_1_container_2,
          host_node: grid_1_service_1_container_2.host_node, # grid_1_node_2
          spec: {
            cpu: { mask: "0-3" },
            memory: { limit: 1000 }
          },
          cpu: { usage_pct: 30.0 },
          memory: { usage: 300 },
          network: {
            internal: {
              interfaces: ["ethwe"], rx_bytes: 100, tx_bytes: 200, rx_bytes_per_second: 100, tx_bytes_per_second: 200
            },
            external: {
              interfaces: ["eth0"], rx_bytes: 100.5, tx_bytes: 200.5, rx_bytes_per_second: 100.5, tx_bytes_per_second: 200.5
            }
          },
          created_at: Time.parse('2017-03-01 12:00:00 +00:00')
        },
        # 4) Grid 1, Service 1, Container 2 - included in results (second)
        {
          grid: grid_1,
          grid_service: grid_1_service_1,
          container: grid_1_service_1_container_2,
          host_node: grid_1_service_1_container_2.host_node, # grid_1_node_2
          spec: {
            cpu: { mask: "0-2" },
            memory: { limit: 1000 }
          },
          cpu: { usage_pct: 30.0 },
          memory: { usage: 300 },
          network: {
            internal: {
              interfaces: ["ethwe"], rx_bytes: 100, tx_bytes: 200, rx_bytes_per_second: 100, tx_bytes_per_second: 200
            },
            external: {
              interfaces: ["eth0"], rx_bytes: 100.5, tx_bytes: 200.5, rx_bytes_per_second: 100.5, tx_bytes_per_second: 200.5
            }
          },
          created_at: Time.parse('2017-03-01 12:01:00 +00:00')
        },
        # 5) Grid 1, Service 2, Container 2 - not included in results ( wrong service )
        {
          grid: grid_1,
          grid_service: grid_1_service_2,
          container: grid_1_service_2_container_1,
          host_node: grid_1_service_2_container_1.host_node, # grid_1_node_1
          spec: {
            cpu: { mask: "0-1" },
            memory: { limit: 1000 }
          },
          cpu: { usage_pct: 30.0 },
          memory: { usage: 300 },
          network: {
            internal: {
              interfaces: ["ethwe"], rx_bytes: 100, tx_bytes: 200, rx_bytes_per_second: 100, tx_bytes_per_second: 200
            },
            external: {
              interfaces: ["eth0"], rx_bytes: 100.5, tx_bytes: 200.5, rx_bytes_per_second: 100.5, tx_bytes_per_second: 200.5
            }
          },
          created_at: Time.parse('2017-03-01 12:00:00 +00:00')
        },
        # 6) Grid 2, Service 1, Container 1 - not included in results ( wrong grid )
        {
          grid: grid_2,
          grid_service: grid_2_service_1,
          container: grid_2_service_1_container_1,
          host_node: grid_2_service_1_container_1.host_node, # grid_2_node_1
          spec: {
            cpu: { mask: "0-1" },
            memory: { limit: 1000 }
          },
          cpu: { usage_pct: 30.0 },
          memory: { usage: 300 },
          network: {
            internal: {
              interfaces: ["ethwe"], rx_bytes: 100, tx_bytes: 200, rx_bytes_per_second: 100, tx_bytes_per_second: 200
            },
            external: {
              interfaces: ["eth0"], rx_bytes: 100.5, tx_bytes: 200.5, rx_bytes_per_second: 100.5, tx_bytes_per_second: 200.5
            }
          },
          created_at: Time.parse('2017-03-01 12:00:00 +00:00')
        }
      ])
    }

    describe '#get_aggregate_stats_for_service' do
      it 'returns aggregated data by service_id' do
        stats

        from = Time.parse('2017-03-01 12:00:00 +00:00')
        to = Time.parse('2017-03-01 13:00:00 +00:00')
        results = ContainerStat.get_aggregate_stats_for_service(grid_1_service_1.id, from, to)

        # Records #1, #2 and #3
        expect(results[0]["cpu"]).to eq({
          "num_cores" => 6, #2 + 4
          "percent_used" => 45.0, #avg(10 + 20) + 30
        })
        expect(results[0]["memory"]).to eq({
          "used" => 450.0, #avg(100,200) + 300
          "total" => 2000.0 #avg(1000,1000) + 1000
        })
        expect(results[0]["network"]["internal"]).to eq({
          "interfaces" => ["ethwe"],
          "rx_bytes" => 200.0, #avg(100,100) + 100
          "rx_bytes_per_second" => 200.0,
          "tx_bytes" => 400.0, #avg(200,200) + 200
          "tx_bytes_per_second" => 400.0
        })
        expect(results[0]["network"]["external"]).to eq({
          "interfaces" => ["eth0"],
          "rx_bytes" => 201.0, #avg(100.5,100.5) + 100.5
          "rx_bytes_per_second" => 201.0,
          "tx_bytes" => 401.0, #avg(200.5,200.5) + 200.5
          "tx_bytes_per_second" => 401.0
        })
        expect(results[0]["timestamp"]).to eq({
          "year" => 2017,
          "month" => 3,
          "day" => 1,
          "hour" => 12,
          "minute" => 00
        })

        # Record #4
        expect(results[1]["cpu"]).to eq({
          "num_cores" => 3,
          "percent_used" => 30.0
        })
        expect(results[1]["memory"]).to eq({
          "used" => 300.0,
          "total" => 1000.0
        })
        expect(results[1]["network"]["internal"]).to eq({
          "interfaces" => ["ethwe"],
          "rx_bytes" => 100.0,
          "rx_bytes_per_second" => 100.0,
          "tx_bytes" => 200.0,
          "tx_bytes_per_second" => 200.0
        })
        expect(results[1]["network"]["external"]).to eq({
          "interfaces" => ["eth0"],
          "rx_bytes" => 100.5,
          "rx_bytes_per_second" => 100.5,
          "tx_bytes" => 200.5,
          "tx_bytes_per_second" => 200.5
        })
        expect(results[1]["timestamp"]).to eq({
          "year" => 2017,
          "month" => 3,
          "day" => 1,
          "hour" => 12,
          "minute" => 1
        })
      end
    end

  end
end
