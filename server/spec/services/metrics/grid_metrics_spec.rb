require_relative '../../spec_helper'

describe Metrics::GridMetrics do
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
          system: 0.1,
          user: 0.2
        },
        memory: {
          total: 1000,
          used: 250
        },
        filesystem: [{
          total: 1000,
          used: 100
        }],
        network: {
          in_bytes_per_second: 100,
          out_bytes_per_second: 100,
        },
        created_at: Time.parse('2017-03-01 11:15:30 +00:00')
      },
      { # 2) This is included in first metric for grid
        grid: grid,
        host_node: node,
        cpu: {
          system: 0.05,
          user: 0.05
          # .1 used
        },
        memory: {
          used: 500,
          total: 1000
          # .5 used
        },
        filesystem: [{
          used: 200,
          total: 1000
          # .2 used
        }],
        network: {
          in_bytes_per_second: 100,
          out_bytes_per_second: 100,
        },
        created_at: Time.parse('2017-03-01 12:15:30 +00:00')
      },
      { # 3) This is skipped (wrong grid)
        grid: other_grid,
        host_node: other_node,
        cpu: {
          system: 0.05,
          user: 0.05
          # .1 used
        },
        memory: {
          used: 500,
          total: 1000
          # .5 used
        },
        filesystem: [{
          used: 200,
          total: 1000
          # .2 used
        }],
        network: {
          in_bytes_per_second: 100,
          out_bytes_per_second: 100,
        },
        created_at: Time.parse('2017-03-01 12:15:30 +00:00')
      },
      { # 4) This is included in first metric for grid
        grid: grid,
        host_node: second_node,
        cpu: {
          system: 0.05,
          user: 0.05
          # .1 used
        },
        memory: {
          used: 500,
          total: 1000
          # .5 used
        },
        filesystem: [{
          used: 200,
          total: 1000
          # .2 used
        }],
        network: {
          in_bytes_per_second: 100,
          out_bytes_per_second: 100,
        },
        created_at: Time.parse('2017-03-01 12:15:30 +00:00')
      },
      { # 5) This is included in first metric for grid
        grid: grid,
        host_node: node,
        cpu: {
          user: 0.4,
          system: 0.3
          # .7 used
        },
        memory: {
          used: 100,
          total: 1000
          # .1 used
        },
        filesystem: [{
          used: 800,
          total: 2000
          # .4 used
        }],
        network: {
          in_bytes_per_second: 200,
          out_bytes_per_second: 300,
        },
        created_at: Time.parse('2017-03-01 12:15:45 +00:00')
      },
      { # 6) This is included in second metric for grid
        grid: grid,
        host_node: node,
        cpu: {
          user: 0.25,
          system: 0.25
          # .5 used
        },
        memory: {
          used: 600,
          total: 2000
          # .3 used
        },
        filesystem: [{
          used: 500,
          total: 1000
          # .5 used
        }],
        network: {
          in_bytes_per_second: 400,
          out_bytes_per_second: 500,
        },
        created_at: Time.parse('2017-03-01 12:16:45 +00:00')
      },
      { # 7) this record should be skipped
        grid: grid,
        host_node: node,
        cpu: {
          user: 0.2,
          system: 0.1
        },
        memory: {
          used: 250,
          total: 1000
        },
        filesystem: [{
          used: 100,
          total: 1000
        }],
        network: {
          in_bytes_per_second: 200,
          out_bytes_per_second: 300,
        },
        created_at: Time.parse('2017-03-01 13:15:30 +00:00')
      }
    ])
  }

  describe '#fetch' do
    it 'returns aggregated data by grid_id' do
      stats
      from = Time.parse('2017-03-01 12:00:00 +00:00')
      to = Time.parse('2017-03-01 13:00:00 +00:00')
      results = Metrics::GridMetrics.fetch(grid.id, from, to)

      expect(results).to eq({
        from_time: Time.parse('2017-03-01 12:00:00 +00:00'),
        to_time: Time.parse('2017-03-01 13:00:00 +00:00'),
        stats: [
          {
            # Records #2, #4 and #5.
            # For same host_node_id, all fields are averaged except data_points is summed.
            # Then results are summed across node ids, except percent values are averaged.
            data_points: 3,
            cpu_usage_percent: 0.25,
            memory_used_bytes: 800.0,
            memory_total_bytes: 2000.0,
            memory_used_percent: 0.4,
            filesystem_used_bytes: 700.0,
            filesystem_total_bytes: 2500.0,
            filesystem_used_percent: 0.25,
            network_in_bytes_per_second: 250,
            network_out_bytes_per_second: 300,
            timestamp: Time.parse('2017-03-01 12:15:00 +0000')
          },
          {
            # Record #5
            data_points: 1,
            cpu_usage_percent: 0.5,
            memory_used_bytes: 600.0,
            memory_total_bytes: 2000.0,
            memory_used_percent: 0.3,
            filesystem_used_bytes: 500.0,
            filesystem_total_bytes: 1000.0,
            filesystem_used_percent: 0.5,
            network_in_bytes_per_second: 400,
            network_out_bytes_per_second: 500,
            timestamp: Time.parse('2017-03-01 12:16:00 +0000')
          }]
        })
    end
  end
end
