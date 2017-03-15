class HostNodeStat
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :load, type: Hash
  field :memory, type: Hash
  field :filesystem, type: Array
  field :usage, type: Hash
  field :cpu, type: Hash
  field :network, type: Array

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
          '$lte': to_time
        }
      }
    },
    # Flatten filesystem and network arrays
    {
      '$unwind': '$filesystem',
    },
    {
      '$unwind': '$network',
    },
    # Aggregate (sum) file system sub-array
    {
      '$group': {
        _id: {
          created_at: '$created_at',
          cpu: '$cpu',
          memory: '$memory',
          network: '$network',
        },
        filesystem_used: {
          '$sum': '$filesystem.used'
        },
        filesystem_total: {
          '$sum': '$filesystem.total'
        }
      }
    },
    # Aggregate per minute, per network interface
    {
      '$group': {
        _id: {
          year: { '$year': '$_id.created_at' },
          month: { '$month': '$_id.created_at' },
          day: { '$dayOfMonth': '$_id.created_at' },
          hour: { '$hour': '$_id.created_at' },
          minute: { '$minute': '$_id.created_at' },
          network_name: '$_id.network.name'
        },
        cpu_num_cores: {
          '$avg': '$_id.cpu.num_cores'
        },
        cpu_percent_used: {
          '$avg': { '$add': ['$_id.cpu.user', '$_id.cpu.system'] }
        },
        filesystem_used: {
          '$avg': '$filesystem_used'
        },
        filesystem_total: {
          '$avg': '$filesystem_total'
        },
        memory_used: {
          '$avg': '$_id.memory.used'
        },
        memory_total: {
          '$avg': '$_id.memory.total'
        },
        network_rx_bytes: {
          '$avg': '$_id.network.rx_bytes'
        },
        network_rx_errors: {
          '$avg': '$_id.network.rx_errors'
        },
        network_rx_dropped: {
          '$avg': '$_id.network.rx_dropped'
        },
        network_tx_bytes: {
          '$avg': '$_id.network.tx_bytes'
        },
        network_tx_errors: {
          '$avg': '$_id.network.tx_errors'
        },
        max_timestamp: {
          '$max': '$_id.created_at'
        }
      }
    },
    # Aggregate network values to a sub array
    {
      '$group': {
        _id: {
          year: '$_id.year',
          month: '$_id.month',
          day: '$_id.day',
          hour: '$_id.hour',
          minute: '$_id.minute'
        },
        cpu_num_cores: {
          '$avg': '$cpu_num_cores'
        },
        cpu_percent_used: {
          '$avg': '$cpu_percent_used'
        },
        memory_used: {
          '$avg': '$memory_used'
        },
        memory_total: {
          '$avg': '$memory_total'
        },
        filesystem_used: {
          '$avg': '$filesystem_used'
        },
        filesystem_total: {
          '$avg': '$filesystem_total'
        },
        network: {
          '$addToSet': {
              name: '$_id.network_name',
              rx_bytes: '$network_rx_bytes',
              rx_errors: '$network_rx_errors',
              rx_dropped: '$network_rx_dropped',
              tx_bytes: '$network_tx_bytes',
              tx_errors: '$network_tx_errors'
          }
        },
        max_timestamp: {
          '$max': '$max_timestamp'
        }
      }
    },
    {
      '$sort': { 'max_timestamp': 1 }
    },
    {
      '$project': {
        _id: 0,
        timestamp: '$_id',
        cpu_num_cores: 1,
        cpu_percent_used: 1,
        memory_used: 1,
        memory_total: 1,
        filesystem_used: 1,
        filesystem_total: 1,
        network: 1
      }
    }])
  end

  def self.get_aggregate_stats_for_grid(grid_id, from_time, to_time)
    self.collection.aggregate([
    {
      '$match': {
        grid_id: grid_id,
        created_at: {
          '$gte': from_time,
          '$lte': to_time
        }
      }
    },
    # Flatten filesystem and network arrays
    {
      '$unwind': '$filesystem',
    },
    {
      '$unwind': '$network',
    },
    # Aggregate (sum) file system sub-array per node
    {
      '$group': {
        _id: {
          created_at: '$created_at',
          host_node_id: '$host_node_id',
          cpu: '$cpu',
          memory: '$memory',
          network: '$network',
        },
        filesystem_used: {
          '$sum': '$filesystem.used'
        },
        filesystem_total: {
          '$sum': '$filesystem.total'
        }
      }
    },
    # Aggregate per minute, per network interface, per node
    {
      '$group': {
        _id: {
          year: { '$year': '$_id.created_at' },
          month: { '$month': '$_id.created_at' },
          day: { '$dayOfMonth': '$_id.created_at' },
          hour: { '$hour': '$_id.created_at' },
          minute: { '$minute': '$_id.created_at' },
          host_node_id: '$_id.host_node_id',
          network_name: '$_id.network.name'
        },
        cpu_num_cores: {
          '$avg': '$_id.cpu.num_cores'
        },
        cpu_percent_used: {
          '$avg': { '$add': ['$_id.cpu.user', '$_id.cpu.system'] }
        },
        filesystem_used: {
          '$avg': '$filesystem_used'
        },
        filesystem_total: {
          '$avg': '$filesystem_total'
        },
        memory_used: {
          '$avg': '$_id.memory.used'
        },
        memory_total: {
          '$avg': '$_id.memory.total'
        },
        network_rx_bytes: {
          '$avg': '$_id.network.rx_bytes'
        },
        network_rx_errors: {
          '$avg': '$_id.network.rx_errors'
        },
        network_rx_dropped: {
          '$avg': '$_id.network.rx_dropped'
        },
        network_tx_bytes: {
          '$avg': '$_id.network.tx_bytes'
        },
        network_tx_errors: {
          '$avg': '$_id.network.tx_errors'
        },
        max_timestamp: {
          '$max': '$_id.created_at'
        }
      }
    },
    # Aggregate node values
    {
      '$group': {
        _id: {
          year: '$_id.year',
          month: '$_id.month',
          day: '$_id.day',
          hour: '$_id.hour',
          minute: '$_id.minute',
          network_name: '$_id.network_name'
        },
        cpu_num_cores: {
          '$sum': '$cpu_num_cores'
        },
        cpu_percent_used: {
          '$avg': '$cpu_percent_used'
        },
        filesystem_used: {
          '$sum': '$filesystem_used'
        },
        filesystem_total: {
          '$sum': '$filesystem_total'
        },
        memory_used: {
          '$sum': '$memory_used'
        },
        memory_total: {
          '$sum': '$memory_total'
        },
        network_rx_bytes: {
          '$sum': '$network_rx_bytes'
        },
        network_rx_errors: {
          '$sum': '$network_rx_errors'
        },
        network_rx_dropped: {
          '$sum': '$network_rx_dropped'
        },
        network_tx_bytes: {
          '$sum': '$network_tx_bytes'
        },
        network_tx_errors: {
          '$sum': '$network_tx_errors'
        },
        max_timestamp: {
          '$max': '$max_timestamp'
        }
      }
    },
    # Aggregate network values to a sub array
    {
      '$group': {
        _id: {
          year: '$_id.year',
          month: '$_id.month',
          day: '$_id.day',
          hour: '$_id.hour',
          minute: '$_id.minute'
        },
        cpu_num_cores: {
          '$avg': '$cpu_num_cores'
        },
        cpu_percent_used: {
          '$avg': '$cpu_percent_used'
        },
        memory_used: {
          '$avg': '$memory_used'
        },
        memory_total: {
          '$avg': '$memory_total'
        },
        filesystem_used: {
          '$avg': '$filesystem_used'
        },
        filesystem_total: {
          '$avg': '$filesystem_total'
        },
        network: {
          '$addToSet': {
              name: '$_id.network_name',
              rx_bytes: '$network_rx_bytes',
              rx_errors: '$network_rx_errors',
              rx_dropped: '$network_rx_dropped',
              tx_bytes: '$network_tx_bytes',
              tx_errors: '$network_tx_errors'
          }
        },
        max_timestamp: {
          '$max': '$max_timestamp'
        }
      }
    },
    {
      '$sort': { 'max_timestamp': 1 }
    },
    {
      '$project': {
        _id: 0,
        timestamp: '$_id',
        cpu_num_cores: 1,
        cpu_percent_used: 1,
        memory_used: 1,
        memory_total: 1,
        filesystem_used: 1,
        filesystem_total: 1,
        network: 1
      }
    }])
  end
end
