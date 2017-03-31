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
        cpu_percent_used: {
          '$avg': {
            '$add': [
              { '$ifNull': ['$cpu.user', 0] },
              { '$ifNull': ['$cpu.system', 0] },
              { '$ifNull': ['$cpu.nice', 0] }
            ]
          }
        },

        memory_used: { '$avg': '$memory.used' },
        memory_total: { '$avg': '$memory.total' },
        memory_free: { '$avg': '$memory.free' },
        memory_active: { '$avg': '$memory.active' },
        memory_inactive: { '$avg': '$memory.inactive' },
        memory_cached: { '$avg': '$memory.cached' },
        memory_buffers: { '$avg': '$memory.buffers' },

        network_internal_interfaces: { '$first': '$network.internal.interfaces' },
        network_internal_rx_bytes: { '$avg': '$network.internal.rx_bytes' },
        network_internal_rx_bytes_per_second: { '$avg': '$network.internal.rx_bytes_per_second' },
        network_internal_tx_bytes: { '$avg': '$network.internal.tx_bytes' },
        network_internal_tx_bytes_per_second: { '$avg': '$network.internal.tx_bytes_per_second' },
        network_external_interfaces: { '$first': '$network.external.interfaces' },
        network_external_rx_bytes: { '$avg': '$network.external.rx_bytes' },
        network_external_rx_bytes_per_second: { '$avg': '$network.external.rx_bytes_per_second' },
        network_external_tx_bytes: { '$avg': '$network.external.tx_bytes' },
        network_external_tx_bytes_per_second: { '$avg': '$network.external.tx_bytes_per_second' },

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
          total: '$memory_total',
          free: '$memory_free',
          active: '$memory_active',
          inactive: '$memory_inactive',
          cached: '$memory_cached',
          buffers: '$memory_buffers'
        },
        network: {
          internal: {
            interfaces: '$network_internal_interfaces',
            rx_bytes: '$network_internal_rx_bytes',
            rx_bytes_per_second: '$network_internal_rx_bytes_per_second',
            tx_bytes: '$network_internal_tx_bytes',
            tx_bytes_per_second: '$network_internal_tx_bytes_per_second'
          },
          external: {
            interfaces: '$network_external_interfaces',
            rx_bytes: '$network_external_rx_bytes',
            rx_bytes_per_second: '$network_external_rx_bytes_per_second',
            tx_bytes: '$network_external_tx_bytes',
            tx_bytes_per_second: '$network_external_tx_bytes_per_second'
          }
        },
        filesystem: {
          used: '$filesystem_used',
          total: '$filesystem_total'
        }
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
        cpu_percent_used: {
          '$avg': {
            '$add': [
              { '$ifNull': ['$cpu.user', 0] },
              { '$ifNull': ['$cpu.system', 0] },
              { '$ifNull': ['$cpu.nice', 0] }
            ]
          }
        },

        memory_used: { '$avg': '$memory.used' },
        memory_total: { '$avg': '$memory.total' },
        memory_free: { '$avg': '$memory.free' },
        memory_active: { '$avg': '$memory.active' },
        memory_inactive: { '$avg': '$memory.inactive' },
        memory_cached: { '$avg': '$memory.cached' },
        memory_buffers: { '$avg': '$memory.buffers' },

        network_internal_interfaces: { '$first': '$network.internal.interfaces' },
        network_internal_rx_bytes: { '$avg': '$network.internal.rx_bytes' },
        network_internal_rx_bytes_per_second: { '$avg': '$network.internal.rx_bytes_per_second' },
        network_internal_tx_bytes: { '$avg': '$network.internal.tx_bytes' },
        network_internal_tx_bytes_per_second: { '$avg': '$network.internal.tx_bytes_per_second' },
        network_external_interfaces: { '$first': '$network.external.interfaces' },
        network_external_rx_bytes: { '$avg': '$network.external.rx_bytes' },
        network_external_rx_bytes_per_second: { '$avg': '$network.external.rx_bytes_per_second' },
        network_external_tx_bytes: { '$avg': '$network.external.tx_bytes' },
        network_external_tx_bytes_per_second: { '$avg': '$network.external.tx_bytes_per_second' },

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
        cpu_percent_used: { '$sum': '$cpu_percent_used' },

        memory_used: { '$sum': '$memory_used' },
        memory_total: { '$sum': '$memory_total' },
        memory_free: { '$sum': '$memory_free' },
        memory_active: { '$sum': '$memory_active' },
        memory_inactive: { '$sum': '$memory_inactive' },
        memory_cached: { '$sum': '$memory_cached' },
        memory_buffers: { '$sum': '$memory_buffers' },

        network_internal_interfaces: { '$first': '$network_internal_interfaces' },
        network_internal_rx_bytes: { '$sum': '$network_internal_rx_bytes' },
        network_internal_rx_bytes_per_second: { '$sum': '$network_internal_rx_bytes_per_second' },
        network_internal_tx_bytes: { '$sum': '$network_internal_tx_bytes' },
        network_internal_tx_bytes_per_second: { '$sum': '$network_internal_tx_bytes_per_second' },
        network_external_interfaces: { '$first': '$network_external_interfaces' },
        network_external_rx_bytes: { '$sum': '$network_external_rx_bytes' },
        network_external_rx_bytes_per_second: { '$sum': '$network_external_rx_bytes_per_second' },
        network_external_tx_bytes: { '$sum': '$network_external_tx_bytes' },
        network_external_tx_bytes_per_second: { '$sum': '$network_external_tx_bytes_per_second' },

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
          total: '$memory_total',
          free: '$memory_free',
          active: '$memory_active',
          inactive: '$memory_inactive',
          cached: '$memory_cached',
          buffers: '$memory_buffers'
        },
        network: {
          internal: {
            interfaces: '$network_internal_interfaces',
            rx_bytes: '$network_internal_rx_bytes',
            rx_bytes_per_second: '$network_internal_rx_bytes_per_second',
            tx_bytes: '$network_internal_tx_bytes',
            tx_bytes_per_second: '$network_internal_tx_bytes_per_second'
          },
          external: {
            interfaces: '$network_external_interfaces',
            rx_bytes: '$network_external_rx_bytes',
            rx_bytes_per_second: '$network_external_rx_bytes_per_second',
            tx_bytes: '$network_external_tx_bytes',
            tx_bytes_per_second: '$network_external_tx_bytes_per_second'
          }
        },
        filesystem: {
          used: '$filesystem_used',
          total: '$filesystem_total'
        }
      }
    }])
  end
end
