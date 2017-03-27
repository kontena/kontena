
describe HostNodeStat do
  it { should be_timestamped_document }
  it { should have_fields(:memory, :load, :usage, :cpu).of_type(Hash)}
  it { should have_fields(:filesystem, :network).of_type(Array)}

  it { should belong_to(:grid) }
  it { should belong_to(:host_node) }

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(host_node_id: 1) }
  it { should have_index_for(host_node_id:1, created_at: 1) }

  describe 'aggregations' do
    let(:grid) { Grid.create!(name: 'test-grid') }
    let(:other_grid) { Grid.create!(name: 'other-grid') }
    let(:node) { HostNode.create!(grid: grid, name: 'test-node') }
    let(:second_node) { HostNode.create!(grid: grid, name: 'second-node') }
    let(:other_node) { HostNode.create!(grid: other_grid, name: 'other-node') }
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
            total: 1000,
            used: 250
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
          network: [{
            name: "n1",
            rx_bytes: 100,
            tx_bytes: 100,
          }, {
            name: "n2",
            rx_bytes: 100.5,
            tx_bytes: 100.5,
          }],
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
            total: 1000
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
          network: [{
            name: "n1",
            rx_bytes: 100,
            tx_bytes: 100,
          }, {
            name: "n2",
            rx_bytes: 100.5,
            tx_bytes: 100.5,
          }],
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
            total: 1000
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
          network: [{
            name: "n1",
            rx_bytes: 100,
            tx_bytes: 100,
          }, {
            name: "n2",
            rx_bytes: 100.5,
            tx_bytes: 100.5,
          }],
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
            total: 1000
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
          network: [{
            name: "n1",
            rx_bytes: 100,
            tx_bytes: 100,
          }, {
            name: "n2",
            rx_bytes: 100.5,
            tx_bytes: 100.5
          }],
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
            total: 1000
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
          network: [{
            name: "n1",
            rx_bytes: 200,
            tx_bytes: 300,
          }, {
            name: "n2",
            rx_bytes: 200.5,
            tx_bytes: 300.5,
          }],
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
            total: 2000
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
          network: [{
            name: "n1",
            rx_bytes: 400,
            tx_bytes: 500,
          }, {
            name: "n2",
            rx_bytes: 400.5,
            tx_bytes: 500.5,
          }],
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
            total: 1000
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
          network: [{
            name: "n1",
            rx_bytes: 200,
            tx_bytes: 300,
          }, {
            name: "n2",
            rx_bytes: 200.5,
            tx_bytes: 300.5,
          }],
          created_at: Time.parse('2017-03-01 13:15:30 +00:00')
        }
      ])
    }

    describe '#get_aggregate_stats_for_node' do
      it 'returns aggregated data by node_id' do
        stats
        from = Time.parse('2017-03-01 12:00:00 +00:00')
        to = Time.parse('2017-03-01 13:00:00 +00:00')
        results = HostNodeStat.get_aggregate_stats_for_node(node.id, from, to, "n1")

        # Records #2 and #5.
        expect(results[0]["cpu"]).to eq({
          "num_cores" => 1.0, #avg(1,1)
          "percent_used" => 0.39999999999999997, #avg(.1, .7)
        })
        expect(results[0]["memory"]).to eq({
          "used" => 300.0, #avg(500, 100)
          "total" => 1000.0 #avg(1000, 1000)
        })
        expect(results[0]["filesystem"]).to eq({
          "used" => 1000.0, #avg( 200+200, 800+800 )
          "total" => 3000.0 #avg( 1000+1000, 2000+2000 )
        })
        expect(results[0]["network"]).to eq({
          "name" => "n1",
          "rx_bytes" => 150.0, #avg(100, 200)
          "rx_errors" => 0.0,
          "rx_dropped" => 0.0,
          "tx_bytes" => 200.0, #avg(100, 300)
          "tx_errors" => 0.0
        })
        expect(results[0]["timestamp"]).to eq({
          "year" => 2017,
          "month" => 3,
          "day" => 1,
          "hour" => 12,
          "minute" => 15
        })

        # Record #6
        expect(results[1]["cpu"]).to eq({
          "num_cores" => 1.0,
          "percent_used" => 0.5
        })
        expect(results[1]["memory"]).to eq({
          "used" => 600.0,
          "total" => 2000.0
        })
        expect(results[1]["filesystem"]).to eq({
          "used" => 1000.0, # 500+500
          "total" => 2000.0 # 1000+1000
        })
        expect(results[1]["network"]).to eq({
          "name" => "n1",
          "rx_bytes" => 400.0,
          "rx_errors" => 0.0,
          "rx_dropped" => 0.0,
          "tx_bytes" => 500.0,
          "tx_errors" => 0.0
        })
        expect(results[1]["timestamp"]).to eq({
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
        results = HostNodeStat.get_aggregate_stats_for_grid(grid.id, from, to, "n2")

        # Records #2, #4 and #5.
        expect(results[0]["cpu"]).to eq({
          "num_cores" => 3.0, # avg(1,1) + 2
          "percent_used" => 0.25, #avg( avg(.1, .7) + .1 )
        })
        expect(results[0]["memory"]).to eq({
          "used" => 800.0, # avg(500, 100) + 500
          "total" => 2000.0 # avg(1000, 1000) + 1000
        })
        expect(results[0]["filesystem"]).to eq({
          "used" => 1400.0, # avg(200+200, 800+800) + (200+200)
          "total" => 5000.0 # avg(1000+1000, 2000+2000) + (1000+1000)
        })
        expect(results[0]["network"]).to eq({
          "name" => "n2",
          "rx_bytes" => 251.0, # avg(100.5, 200.5) + 100.5
          "rx_errors" => 0.0,
          "rx_dropped" => 0.0,
          "tx_bytes" => 301.0, # avg(100.5, 300.5) + 100.5
          "tx_errors" => 0.0
        })
        expect(results[0]["timestamp"]).to eq({
          "year" => 2017,
          "month" => 3,
          "day" => 1,
          "hour" => 12,
          "minute" => 15
        })

        # Record #6
        expect(results[1]["cpu"]).to eq({
          "num_cores" => 1.0,
          "percent_used" => 0.5
        })
        expect(results[1]["memory"]).to eq({
          "used" => 600.0,
          "total" => 2000.0
        })
        expect(results[1]["filesystem"]).to eq({
          "used" => 1000.0, # 500+500
          "total" => 2000.0 # 1000+1000
        })
        expect(results[1]["network"]).to eq({
          "name" => "n2",
          "rx_bytes" => 400.5,
          "rx_errors" => 0.0,
          "rx_dropped" => 0.0,
          "tx_bytes" => 500.5,
          "tx_errors" => 0.0
        })
        expect(results[1]["timestamp"]).to eq({
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
