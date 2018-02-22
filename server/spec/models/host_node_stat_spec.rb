
describe HostNodeStat do
  it { should be_timestamped_document }
  it { should have_fields(:memory, :load, :usage, :cpu, :network).of_type(Hash)}
  it { should have_fields(:filesystem).of_type(Array)}

  it { should belong_to(:grid) }
  it { should belong_to(:host_node) }

  it { should have_index_for(grid_id: 1).with_options(background: true) }
  it { should have_index_for(host_node_id: 1).with_options(background: true) }
  it { should have_index_for(host_node_id:1, created_at: 1).with_options(background: true) }

  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:node) { grid.create_node!('test-node') }

  describe '.latest' do
    it 'returns latest stat item' do
      node.host_node_stats.create
      last = node.host_node_stats.create
      expect(described_class.latest).to eq(last)
    end

    it 'returns nil if no stats' do
      expect(described_class.latest).to be_nil
    end
  end

  describe 'aggregations' do
    let(:other_grid) { Grid.create!(name: 'other-grid') }
    let(:second_node) { grid.create_node!('second-node') }
    let(:other_node) { other_grid.create_node!('other-node') }
    let(:stats) {
      HostNodeStat.create([
        { # 1) this record should be skipped
          grid: grid,
          host_node: node,
          cpu: {
            num_cores: 1,
            system: 0.1,
            user: 0.2
          },
          memory: {
            used: 250,
            total: 1000,
            free: 750,
            active: 500,
            inactive: 500,
            cached: 100,
            buffers: 100
          },
          filesystem: [{
            name: "fs1",
            total: 1000,
            used: 100
          }, {
            name: "fs2",
            total: 1000,
            used: 100
          }],
          network: {
            internal: {
              interfaces: ["weave", "vethwe123"],
              rx_bytes: 100,
              rx_bytes_per_second: 100,
              tx_bytes: 100,
              tx_bytes_per_second: 100,
            },
            external: {
              interfaces: ["docker0"],
              rx_bytes: 100.5,
              rx_bytes_per_second: 100.5,
              tx_bytes: 100.5,
              tx_bytes_per_second: 100.5,
            }
          },
          created_at: Time.parse('2017-03-01 11:15:30 +00:00')
        },
        { # 2) This is included in first metric for grid
          grid: grid,
          host_node: node,
          cpu: {
            num_cores: 1,
            system: 0.05,
            user: 0.05
            # .1 used
          },
          memory: {
            used: 500,
            total: 1000,
            free: 500,
            active: 500,
            inactive: 500,
            cached: 100,
            buffers: 100
          },
          filesystem: [{
            name: "fs1",
            used: 200,
            total: 1000
          }, {
            name: "fs2",
            used: 200,
            total: 1000
          }],
          network: {
            internal: {
              interfaces: ["weave", "vethwe123"],
              rx_bytes: 100,
              rx_bytes_per_second: 100,
              tx_bytes: 100,
              tx_bytes_per_second: 100,
            },
            external: {
              interfaces: ["docker0"],
              rx_bytes: 100.5,
              rx_bytes_per_second: 100.5,
              tx_bytes: 100.5,
              tx_bytes_per_second: 100.5,
            }
          },
          created_at: Time.parse('2017-03-01 12:15:30 +00:00')
        },
        { # 3) This is skipped (wrong grid)
          grid: other_grid,
          host_node: other_node,
          cpu: {
            num_cores: 2,
            system: 0.05,
            user: 0.05
            # .1 used
          },
          memory: {
            used: 500,
            total: 1000,
            free: 500,
            active: 500,
            inactive: 500,
            cached: 100,
            buffers: 100
          },
          filesystem: [{
            name: "fs1",
            used: 200,
            total: 1000
          }, {
            name: "fs2",
            used: 200,
            total: 1000
          }],
          network: {
            internal: {
              interfaces: ["weave", "vethwe123"],
              rx_bytes: 100,
              rx_bytes_per_second: 100,
              tx_bytes: 100,
              tx_bytes_per_second: 100,
            },
            external: {
              interfaces: ["docker0"],
              rx_bytes: 100.5,
              rx_bytes_per_second: 100.5,
              tx_bytes: 100.5,
              tx_bytes_per_second: 100.5,
            }
          },
          created_at: Time.parse('2017-03-01 12:15:30 +00:00')
        },
        { # 4) This is included in first metric for grid (grid level test only)
          grid: grid,
          host_node: second_node,
          cpu: {
            num_cores: 2,
            system: 0.05,
            user: 0.05
            # .1 used
          },
          memory: {
            used: 500,
            total: 1000,
            free: 500,
            active: 500,
            inactive: 500,
            cached: 100,
            buffers: 100
          },
          filesystem: [{
            name: "fs1",
            used: 200,
            total: 1000
          }, {
              name: "fs2",
              used: 200,
              total: 1000
          }],
          network: {
            internal: {
              interfaces: ["weave", "vethwe123"],
              rx_bytes: 100,
              rx_bytes_per_second: 100,
              tx_bytes: 100,
              tx_bytes_per_second: 100,
            },
            external: {
              interfaces: ["docker0"],
              rx_bytes: 100.5,
              rx_bytes_per_second: 100.5,
              tx_bytes: 100.5,
              tx_bytes_per_second: 100.5,
            }
          },
          created_at: Time.parse('2017-03-01 12:15:30 +00:00')
        },
        { # 5) This is included in first metric for grid
          grid: grid,
          host_node: node,
          cpu: {
            num_cores: 1,
            user: 0.4,
            system: 0.3
            # .7 used
          },
          memory: {
            used: 100,
            total: 1000,
            free: 900,
            active: 500,
            inactive: 500,
            cached: 100,
            buffers: 100
          },
          filesystem: [{
            name: "fs1",
            used: 800,
            total: 2000
          }, {
            name: "fs2",
            used: 800,
            total: 2000
          }],
          network: {
            internal: {
              interfaces: ["weave", "vethwe123"],
              rx_bytes: 200,
              rx_bytes_per_second: 200,
              tx_bytes: 300,
              tx_bytes_per_second: 300,
            },
            external: {
              interfaces: ["docker0"],
              rx_bytes: 200.5,
              rx_bytes_per_second: 200.5,
              tx_bytes: 300.5,
              tx_bytes_per_second: 300.5,
            }
          },
          created_at: Time.parse('2017-03-01 12:15:45 +00:00')
        },
        { # 6) This is included in second metric for grid
          grid: grid,
          host_node: node,
          cpu: {
            num_cores: 1,
            user: 0.25,
            system: 0.25
            # .5 used
          },
          memory: {
            used: 600,
            total: 2000,
            free: 1400,
            active: 1000,
            inactive: 1000,
            cached: 100,
            buffers: 100
          },
          filesystem: [{
            name: "fs1",
            used: 500,
            total: 1000
          }, {
            name: "fs2",
            used: 500,
            total: 1000
          }],
          network: {
            internal: {
              interfaces: ["weave", "vethwe123"],
              rx_bytes: 400,
              rx_bytes_per_second: 400,
              tx_bytes: 500,
              tx_bytes_per_second: 500,
            },
            external: {
              interfaces: ["docker0"],
              rx_bytes: 400.5,
              rx_bytes_per_second: 400.5,
              tx_bytes: 500.5,
              tx_bytes_per_second: 500.5,
            }
          },
          created_at: Time.parse('2017-03-01 12:16:45 +00:00')
        },
        { # 7) this record should be skipped
          grid: grid,
          host_node: node,
          cpu: {
            num_cores: 1,
            user: 0.2,
            system: 0.1
          },
          memory: {
            used: 250,
            total: 1000,
            free: 750,
            active: 500,
            inactive: 500,
            cached: 100,
            buffers: 100
          },
          filesystem: [{
            name: "fs1",
            used: 100,
            total: 1000
          }, {
            name: "fs2",
            used: 100,
            total: 1000
          }],
          network: {
            internal: {
              interfaces: ["weave", "vethwe123"],
              rx_bytes: 200,
              rx_bytes_per_second: 200,
              tx_bytes: 300,
              tx_bytes_per_second: 300,
            },
            external: {
              interfaces: ["docker0"],
              rx_bytes: 200.5,
              rx_bytes_per_second: 200.5,
              tx_bytes: 300.5,
              tx_bytes_per_second: 300.5,
            }
          },
          created_at: Time.parse('2017-03-01 13:15:30 +00:00')
        }
      ])
    }

    describe '#get_aggregate_stats_for_node' do
      it 'returns aggregated data by node_id' do
        stats
        from = Time.parse('2017-03-01 12:00:00 +00:00')
        to = Time.parse('2017-03-01 13:00:00 +00:00')
        results = HostNodeStat.get_aggregate_stats_for_node(node.id, from, to)

        # Records #2 and #5.
        expect(results.to_a[0]["cpu"]).to eq({
          "num_cores" => 1.0, #avg(1,1)
          "percent_used" => 0.39999999999999997, #avg(.1, .7)
        })
        expect(results.to_a[0]["memory"]).to eq({
          "used" => 300.0,     #avg(500, 100)
          "total" => 1000.0,   #avg(1000, 1000)
          "free" => 700.0,     #avg(500, 900)
          "active" => 500.0,   #avg(500, 500)
          "inactive" => 500.0, #avg(500, 500)
          "cached" => 100.0,   #avg(100, 100)
          "buffers" => 100.0   #avg(100, 100)
        })
        expect(results.to_a[0]["filesystem"]).to eq({
          "used" => 1000.0, #avg( 200+200, 800+800 )
          "total" => 3000.0 #avg( 1000+1000, 2000+2000 )
        })
        expect(results.to_a[0]["network"]["internal"]).to eq({
          "interfaces" => ["weave", "vethwe123"],
          "rx_bytes" => 150.0, #avg(100, 200)
          "rx_bytes_per_second" => 150.0,
          "tx_bytes" => 200.0, #avg(100, 300)
          "tx_bytes_per_second" => 200.0
        })
        expect(results.to_a[0]["network"]["external"]).to eq({
          "interfaces" => ["docker0"],
          "rx_bytes" => 150.5, #avg(100.5, 200.5)
          "rx_bytes_per_second" => 150.5,
          "tx_bytes" => 200.5, #avg(100.5, 300.5)
          "tx_bytes_per_second" => 200.5
        })
        expect(results.to_a[0]["timestamp"]).to eq({
          "year" => 2017,
          "month" => 3,
          "day" => 1,
          "hour" => 12,
          "minute" => 15
        })

        # Record #6
        expect(results.to_a[1]["cpu"]).to eq({
          "num_cores" => 1.0,
          "percent_used" => 0.5
        })
        expect(results.to_a[1]["memory"]).to eq({
          "used" => 600.0,
          "total" => 2000.0,
          "free" => 1400.0,
          "active" => 1000.0,
          "inactive" => 1000.0,
          "cached" => 100.0,
          "buffers" => 100.0
        })
        expect(results.to_a[1]["filesystem"]).to eq({
          "used" => 1000.0, # 500+500
          "total" => 2000.0 # 1000+1000
        })
        expect(results.to_a[1]["network"]["internal"]).to eq({
          "interfaces" => ["weave", "vethwe123"],
          "rx_bytes" => 400.0,
          "rx_bytes_per_second" => 400.0,
          "tx_bytes" => 500.0,
          "tx_bytes_per_second" => 500.0
        })
        expect(results.to_a[1]["network"]["external"]).to eq({
          "interfaces" => ["docker0"],
          "rx_bytes" => 400.5,
          "rx_bytes_per_second" => 400.5,
          "tx_bytes" => 500.5,
          "tx_bytes_per_second" => 500.5
        })
        expect(results.to_a[1]["timestamp"]).to eq({
          "year" => 2017,
          "month" => 3,
          "day" => 1,
          "hour" => 12,
          "minute" => 16
        })
      end
    end

    describe '#get_aggregate_stats_for_grid' do
      it 'returns aggregated data by grid_id' do
        stats
        from = Time.parse('2017-03-01 12:00:00 +00:00')
        to = Time.parse('2017-03-01 13:00:00 +00:00')
        results = HostNodeStat.get_aggregate_stats_for_grid(grid.id, from, to)

        # Records #2, #4 and #5.
        expect(results.to_a[0]["cpu"]).to eq({
          "num_cores" => 3.0,     # avg(1,1) + 2
          "percent_used" => 0.5, # avg(.1, .7) + .1
        })
        expect(results.to_a[0]["memory"]).to eq({
          "used" => 800.0,      # avg(500, 100) + 500
          "total" => 2000.0,    # avg(1000, 1000) + 1000
          "free" => 1200.0,     # avg(500, 900) + 500
          "active" => 1000.0,   # avg(500, 500) + 500
          "inactive" => 1000.0, # avg(500, 500) + 500
          "cached" => 200.0,    # avg(100, 100) + 100
          "buffers" => 200.0,   # avg(100, 100) + 100
        })
        expect(results.to_a[0]["filesystem"]).to eq({
          "used" => 1400.0, # avg(200+200, 800+800) + (200+200)
          "total" => 5000.0 # avg(1000+1000, 2000+2000) + (1000+1000)
        })
        expect(results.to_a[0]["network"]["internal"]).to eq({
          "interfaces" => ["weave", "vethwe123"],
          "rx_bytes" => 250.0, #avg(100, 200) + 100
          "rx_bytes_per_second" => 250.0,
          "tx_bytes" => 300.0, #avg(100, 300) + 100
          "tx_bytes_per_second" => 300.0
        })
        expect(results.to_a[0]["network"]["external"]).to eq({
          "interfaces" => ["docker0"],
          "rx_bytes" => 251.0, #avg(100.5, 200.5) + 100.5
          "rx_bytes_per_second" => 251.0,
          "tx_bytes" => 301.0, #avg(100.5, 300.5) + 100.5
          "tx_bytes_per_second" => 301.0
        })
        expect(results.to_a[0]["timestamp"]).to eq({
          "year" => 2017,
          "month" => 3,
          "day" => 1,
          "hour" => 12,
          "minute" => 15
        })

        # Record #6
        expect(results.to_a[1]["cpu"]).to eq({
          "num_cores" => 1.0,
          "percent_used" => 0.5
        })
        expect(results.to_a[1]["memory"]).to eq({
          "used" => 600.0,
          "total" => 2000.0,
          "free" => 1400.0,
          "active" => 1000.0,
          "inactive" => 1000.0,
          "cached" => 100.0,
          "buffers" => 100.0
        })
        expect(results.to_a[1]["filesystem"]).to eq({
          "used" => 1000.0, # 500+500
          "total" => 2000.0 # 1000+1000
        })
        expect(results.to_a[1]["network"]["internal"]).to eq({
          "interfaces" => ["weave", "vethwe123"],
          "rx_bytes" => 400.0,
          "rx_bytes_per_second" => 400.0,
          "tx_bytes" => 500.0,
          "tx_bytes_per_second" => 500.0
        })
        expect(results.to_a[1]["network"]["external"]).to eq({
          "interfaces" => ["docker0"],
          "rx_bytes" => 400.5,
          "rx_bytes_per_second" => 400.5,
          "tx_bytes" => 500.5,
          "tx_bytes_per_second" => 500.5
        })
        expect(results.to_a[1]["timestamp"]).to eq({
          "year" => 2017,
          "month" => 3,
          "day" => 1,
          "hour" => 12,
          "minute" => 16
        })
      end
    end
  end
end
