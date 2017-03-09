class HostNodeStat
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :load, type: Hash
  field :memory, type: Hash
  field :filesystem, type: Array
  field :usage, type: Hash
  field :cpu, type: Hash
  field :network, type: Hash

  belongs_to :grid
  belongs_to :host_node

  index({ grid_id: 1 })
  index({ host_node_id: 1 })
  index({ host_node_id: 1, created_at: 1 })
  index({ grid_id: 1, created_at: 1 })

  def self.get_aggregate_stats_for_node(node_id, from_time, to_time)
    self.collection.aggregate([
    {
      '$match': {
        host_node_id: node_id,
        created_at: {
          '$gte': from_time,
          '$lt': to_time
        }
      }
    },
    {
      '$sort': {
        created_at: 1
      }
    },
    {
      '$unwind': '$filesystem',
    },
    {
      '$project': {
        _id: 1,
        created_at: 1,
        cpu: {
          system: 1,
          user: 1
        },
        memory: {
          total: 1,
          used: 1
        },
        filesystem: {
          total: 1,
          used: 1
        },
        network: {
          in_bytes_per_second: 1,
          out_bytes_per_second: 1
        }
      }
    },
    {
      '$group': {
        _id: {
          year: { '$year': '$created_at' },
          month: { '$month': '$created_at' },
          day: { '$dayOfMonth': '$created_at' },
          hour: { '$hour': '$created_at' },
          minute: { '$minute': '$created_at' }
        },
        cpu_usage_percent: {
          '$avg': { '$add': ['$cpu.user', '$cpu.system'] }
        },
        memory_used_bytes: {
          '$avg': '$memory.used'
        },
        memory_total_bytes: {
          '$avg': '$memory.total'
        },
        memory_used_percent: {
          '$avg': { '$divide': ['$memory.used', '$memory.total'] }
        },
        filesystem_used_bytes: {
          '$avg': '$filesystem.used'
        },
        filesystem_total_bytes: {
          '$avg': '$filesystem.total'
        },
        filesystem_used_percent: {
          '$avg': { '$divide': ['$filesystem.used', '$filesystem.total'] }
        },
        network_in_bytes_per_second: {
          '$avg': '$network.in_bytes_per_second'
        },
        network_out_bytes_per_second: {
          '$avg': '$network.out_bytes_per_second'
        },
        max_timestamp: {
          '$max': '$created_at'
        },
        data_points: { '$sum': 1 }
      }
    },
    {
      '$sort': { max_timestamp: 1 }
    },
    {
      '$project': {
        _id: 0,
        timestamp: '$_id',
        cpu_usage_percent: 1,
        memory_used_bytes: 1,
        memory_total_bytes: 1,
        memory_used_percent: 1,
        filesystem_used_bytes: 1,
        filesystem_total_bytes: 1,
        filesystem_used_percent: 1,
        network_in_bytes_per_second: 1,
        network_out_bytes_per_second: 1,
        data_points: 1
      }
    }
    ])
  end

  def self.get_aggregate_stats_for_grid(grid_id, from_time, to_time)
    self.collection.aggregate([
    {
      '$match': {
        grid_id: grid_id,
        created_at: {
          '$gte': from_time,
          '$lt': to_time
        }
      }
    },
    {
      '$sort': {
        created_at: 1
      }
    },
    {
      '$unwind': '$filesystem',
    },
    {
      '$project': {
        _id: 1,
        host_node_id: 1,
        created_at: 1,
        cpu: {
          system: 1,
          user: 1
        },
        memory: {
          total: 1,
          used: 1
        },
        filesystem: {
          total: 1,
          used: 1
        },
        network: {
          in_bytes_per_second: 1,
          out_bytes_per_second: 1
        }
      }
    },
    # First group gets us average across each minute, per node
    {
      '$group': {
        _id: {
          host_node_id: '$host_node_id',
          year: { '$year': '$created_at' },
          month: { '$month': '$created_at' },
          day: { '$dayOfMonth': '$created_at' },
          hour: { '$hour': '$created_at' },
          minute: { '$minute': '$created_at' }
        },
        cpu_usage_percent: {
          '$avg': { '$add': ['$cpu.user', '$cpu.system'] }
        },
        memory_used_bytes: {
          '$avg': '$memory.used'
        },
        memory_total_bytes: {
          '$avg': '$memory.total'
        },
        memory_used_percent: {
          '$avg': { '$divide': ['$memory.used', '$memory.total'] }
        },
        filesystem_used_bytes: {
          '$avg': '$filesystem.used'
        },
        filesystem_total_bytes: {
          '$avg': '$filesystem.total'
        },
        filesystem_used_percent: {
          '$avg': { '$divide': ['$filesystem.used', '$filesystem.total'] }
        },
        network_in_bytes_per_second: {
          '$avg': '$network.in_bytes_per_second'
        },
        network_out_bytes_per_second: {
          '$avg': '$network.out_bytes_per_second'
        },
        max_timestamp: {
          '$max': '$created_at'
        },
        data_points: {
          '$sum': 1
        }
      }
    },
    # Second group gets us aggregates in the minute across all nodes
    {
      '$group': {
        _id: {
          year: '$_id.year',
          month: '$_id.month',
          day: '$_id.day',
          hour: '$_id.hour',
          minute: '$_id.minute'
        },
        cpu_usage_percent: {
          '$avg': '$cpu_usage_percent'
        },
        memory_used_bytes: {
          '$sum': '$memory_used_bytes'
        },
        memory_total_bytes: {
          '$sum': '$memory_total_bytes'
        },
        memory_used_percent: {
          '$avg': '$memory_used_percent'
        },
        filesystem_used_bytes: {
          '$sum': '$filesystem_used_bytes'
        },
        filesystem_total_bytes: {
          '$sum': '$filesystem_total_bytes'
        },
        filesystem_used_percent: {
          '$avg': '$filesystem_used_percent'
        },
        network_in_bytes_per_second: {
          '$sum': '$network_in_bytes_per_second'
        },
        network_out_bytes_per_second: {
          '$sum': '$network_out_bytes_per_second'
        },
        max_timestamp: {
          '$max': '$max_timestamp'
        },
        data_points: {
          '$sum': '$data_points'
        }
      }
    },
    {
      '$sort': { max_timestamp: 1 }
    },
    {
      '$project': {
        _id: 0,
        timestamp: '$_id',
        cpu_usage_percent: 1,
        memory_used_bytes: 1,
        memory_total_bytes: 1,
        memory_used_percent: 1,
        filesystem_used_bytes: 1,
        filesystem_total_bytes: 1,
        filesystem_used_percent: 1,
        network_in_bytes_per_second: 1,
        network_out_bytes_per_second: 1,
        data_points: 1
      }
    }
    ])
  end
end
