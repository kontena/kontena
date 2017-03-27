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

  def self.get_aggregate_stats_for_node(node_id, from_time, to_time, network_iface)
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
    # Flatten filesystem and sum values
    {
      '$unwind': '$filesystem',
    },
    {
      '$group': {
        _id: '$_id',
        created_at: { '$first': '$created_at' },
        cpu: { '$first': '$cpu' },
        memory: { '$first': '$memory' },
        network: { '$first': '$network' },
        filesystem_used: { '$sum': '$filesystem.used' },
        filesystem_total: { '$sum': '$filesystem.total' }
      }
    },
    # Flatten network, get selected network interface
    {
      '$unwind': '$network',
    },
    {
      '$match': {
        'network.name': network_iface
      }
    },
    {
      '$group': {
        _id: '$_id',
        created_at: { '$first': '$created_at' },
        cpu: { '$first': '$cpu' },
        memory: { '$first': '$memory' },
        network_name: { '$first': '$network.name' },
        network_rx_bytes: { '$first': '$network.rx_bytes' },
        network_rx_errors: { '$first': '$network.rx_errors' },
        network_rx_dropped: { '$first': '$network.rx_dropped' },
        network_tx_bytes: { '$first': '$network.tx_bytes' },
        network_tx_errors: { '$first': '$network.tx_errors' },
        filesystem_used: { '$first': '$filesystem_used' },
        filesystem_total: { '$first': '$filesystem_total' }
      }
    },
    # Aggregate for each minute
    {
      '$group': {
        _id: {
          year: { '$year': '$created_at' },
          month: { '$month': '$created_at' },
          day: { '$dayOfMonth': '$created_at' },
          hour: { '$hour': '$created_at' },
          minute: { '$minute': '$created_at' }
        },
        created_at: { '$first': '$created_at' },

        cpu_num_cores: { '$avg': '$cpu.num_cores' },
        cpu_percent_used: { '$avg': { '$add': ['$cpu.user', '$cpu.system'] } },

        memory_used: { '$avg': '$memory.used' },
        memory_total: { '$avg': '$memory.total' },

        network_name: { '$first': '$network_name' },
        network_rx_bytes: { '$avg': '$network_rx_bytes' },
        network_rx_errors: { '$avg': '$network_rx_errors' },
        network_rx_dropped: { '$avg': '$network_rx_dropped' },
        network_tx_bytes: { '$avg': '$network_tx_bytes' },
        network_tx_errors: { '$avg': '$network_tx_errors' },

        filesystem_used: { '$avg': '$filesystem_used' },
        filesystem_total: { '$avg': '$filesystem_total' }
      }
    },
    # Sort and project back into useful format
    {
      '$sort': { 'created_at': 1 }
    },
    {
      '$project': {
        _id: 0,
        timestamp: '$_id',
        cpu: {
          num_cores: '$cpu_num_cores',
          percent_used: '$cpu_percent_used'
        },
        memory: {
          used: '$memory_used',
          total: '$memory_total'
        },
        network: {
          name: '$network_name',
          rx_bytes: '$network_rx_bytes',
          rx_errors: '$network_rx_errors',
          rx_dropped: '$network_rx_dropped',
          tx_bytes: '$network_tx_bytes',
          tx_errors: '$network_tx_errors'
        },
        filesystem: {
          used: '$filesystem_used',
          total: '$filesystem_total'
        }
      }
    }])
  end

  def self.get_aggregate_stats_for_grid(grid_id, from_time, to_time, network_iface)
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
    # Flatten filesystem and sum values
    {
      '$unwind': '$filesystem',
    },
    {
      '$group': {
        _id: '$_id',
        host_node_id: { '$first': '$host_node_id' },
        created_at: { '$first': '$created_at' },
        cpu: { '$first': '$cpu' },
        memory: { '$first': '$memory' },
        network: { '$first': '$network' },
        filesystem_used: { '$sum': '$filesystem.used' },
        filesystem_total: { '$sum': '$filesystem.total' }
      }
    },
    # Flatten network, get selected network interface
    {
      '$unwind': '$network',
    },
    {
      '$match': {
        'network.name': network_iface
      }
    },
    {
      '$group': {
        _id: '$_id',
        host_node_id: { '$first': '$host_node_id' },
        created_at: { '$first': '$created_at' },
        cpu: { '$first': '$cpu' },
        memory: { '$first': '$memory' },
        network_name: { '$first': '$network.name' },
        network_rx_bytes: { '$first': '$network.rx_bytes' },
        network_rx_errors: { '$first': '$network.rx_errors' },
        network_rx_dropped: { '$first': '$network.rx_dropped' },
        network_tx_bytes: { '$first': '$network.tx_bytes' },
        network_tx_errors: { '$first': '$network.tx_errors' },
        filesystem_used: { '$first': '$filesystem_used' },
        filesystem_total: { '$first': '$filesystem_total' }
      }
    },
    # Aggregate for each minute
    {
      '$group': {
        _id: {
          year: { '$year': '$created_at' },
          month: { '$month': '$created_at' },
          day: { '$dayOfMonth': '$created_at' },
          hour: { '$hour': '$created_at' },
          minute: { '$minute': '$created_at' },
          host_node_id: '$host_node_id',
        },
        created_at: { '$first': '$created_at' },

        cpu_num_cores: { '$avg': '$cpu.num_cores' },
        cpu_percent_used: { '$avg': { '$add': ['$cpu.user', '$cpu.system'] } },

        memory_used: { '$avg': '$memory.used' },
        memory_total: { '$avg': '$memory.total' },

        network_name: { '$first': '$network_name' },
        network_rx_bytes: { '$avg': '$network_rx_bytes' },
        network_rx_errors: { '$avg': '$network_rx_errors' },
        network_rx_dropped: { '$avg': '$network_rx_dropped' },
        network_tx_bytes: { '$avg': '$network_tx_bytes' },
        network_tx_errors: { '$avg': '$network_tx_errors' },

        filesystem_used: { '$avg': '$filesystem_used' },
        filesystem_total: { '$avg': '$filesystem_total' }
      }
    },
    # Aggregate nodes (sum fields except CPU%, which is averaged)
    {
      '$group': {
        _id: {
          year: { '$year': '$created_at' },
          month: { '$month': '$created_at' },
          day: { '$dayOfMonth': '$created_at' },
          hour: { '$hour': '$created_at' },
          minute: { '$minute': '$created_at' }
        },
        created_at: { '$first': '$created_at' },

        cpu_num_cores: { '$sum': '$cpu_num_cores' },
        cpu_percent_used: { '$avg': '$cpu_percent_used' },

        memory_used: { '$sum': '$memory_used' },
        memory_total: { '$sum': '$memory_total' },

        network_name: { '$first': '$network_name' },
        network_rx_bytes: { '$sum': '$network_rx_bytes' },
        network_rx_errors: { '$sum': '$network_rx_errors' },
        network_rx_dropped: { '$sum': '$network_rx_dropped' },
        network_tx_bytes: { '$sum': '$network_tx_bytes' },
        network_tx_errors: { '$sum': '$network_tx_errors' },

        filesystem_used: { '$sum': '$filesystem_used' },
        filesystem_total: { '$sum': '$filesystem_total' }
      }
    },
    # Sort and project back into useful format
    {
      '$sort': { 'created_at': 1 }
    },
    {
      '$project': {
        _id: 0,
        timestamp: '$_id',
        cpu: {
          num_cores: '$cpu_num_cores',
          percent_used: '$cpu_percent_used'
        },
        memory: {
          used: '$memory_used',
          total: '$memory_total'
        },
        network: {
          name: '$network_name',
          rx_bytes: '$network_rx_bytes',
          rx_errors: '$network_rx_errors',
          rx_dropped: '$network_rx_dropped',
          tx_bytes: '$network_tx_bytes',
          tx_errors: '$network_tx_errors'
        },
        filesystem: {
          used: '$filesystem_used',
          total: '$filesystem_total'
        }
      }
    }])
  end
end
