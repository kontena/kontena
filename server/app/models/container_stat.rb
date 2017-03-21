class ContainerStat
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :spec, type: Hash
  field :cpu, type: Hash
  field :memory, type: Hash
  field :filesystem, type: Array
  field :diskio, type: Hash
  field :network, type: Hash

  belongs_to :grid
  belongs_to :host_node
  belongs_to :grid_service
  belongs_to :container

  index({ grid_id: 1 })
  index({ grid_service_id: 1 })
  index({ container_id: 1 })
  index({ created_at: 1 })
  index({ grid_service_id: 1, created_at: 1 })

  def update_network_stats(interface_name)
    # Odds are, cAdvisor did not give us meaningful network stats at the
    # root network level, so try to use some other interface.
    return unless network

    if (network["name"] != interface_name)
      interfaces = network["interfaces"].select { |iface| iface["name"] == interface_name }

      if (interfaces.size > 0)
        interfaces[0].each { |key,val| network[key] = interfaces[0][key] }
      end
    end
  end

  def self.calculate_num_cores(cpu_mask)
    if cpu_mask
      cpu_mask.split('-').last.to_i + 1
    else
      1
    end
  end

  def self.get_aggregate_stats_for_service(service_id, from_time, to_time, network_iface)
    self.collection.aggregate([
    {
      '$match': {
        grid_service_id: service_id,
        created_at: {
          '$gte': from_time,
          '$lte': to_time
        }
      }
    },
    {
      '$unwind': '$network.interfaces'
    },
    {
      '$match': {
        'network.interfaces.name': network_iface
      }
    },
    {
      '$group': {
        _id: {
          year: { '$year': '$created_at' },
          month: { '$month': '$created_at' },
          day: { '$dayOfMonth': '$created_at' },
          hour: { '$hour': '$created_at' },
          minute: { '$minute': '$created_at' },
          container_id: '$container_id'
        },
        created_at: { '$first': '$created_at' },

        cpu_mask: { '$first': '$spec.cpu.mask' },
        cpu_percent_used: { '$avg': '$cpu.usage_pct' },

        memory_used: { '$avg': '$memory.usage' },
        memory_total: { '$first': '$spec.memory.limit' },

        network_name: { '$first': '$network.interfaces.name' },
        network_rx_bytes: { '$avg': '$network.interfaces.rx_bytes' },
        network_rx_errors: { '$avg': '$network.interfaces.rx_errors' },
        network_rx_dropped: { '$avg': '$network.interfaces.rx_dropped' },
        network_tx_bytes: { '$avg': '$network.interfaces.tx_bytes' },
        network_tx_errors: { '$avg': '$network.interfaces.tx_errors' }
      }
    },
    {
      '$group': {
        _id: {
          year: '$_id.year',
          month: '$_id.month',
          day: '$_id.day',
          hour: '$_id.hour',
          minute: '$_id.minute'
        },
        created_at: { '$first': '$created_at' },

        cpu_mask: { '$first': '$cpu_mask' },
        cpu_percent_used: { '$avg': '$cpu_percent_used' },

        memory_used: { '$sum': '$memory_used' },
        memory_total: { '$sum': '$memory_total' },

        network_name: { '$first': '$network_name' },
        network_rx_bytes: { '$sum': '$network_rx_bytes' },
        network_rx_errors: { '$sum': '$network_rx_errors' },
        network_rx_dropped: { '$sum': '$network_rx_dropped' },
        network_tx_bytes: { '$sum': '$network_tx_bytes' },
        network_tx_errors: { '$sum': '$network_tx_errors' }
      }
    },
    {
      '$sort': { 'created_at': 1 }
    },
    {
      '$project': {
        _id: 0,
        timestamp: '$_id',
        cpu: {
          mask: '$cpu_mask',
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
        }
      }
    }
    ]).map do |stat|
      # convert CPU mask to num_cores
      stat["cpu"]["num_cores"] = calculate_num_cores(stat["cpu"]["mask"])
      stat["cpu"].delete("mask")
      stat
    end
  end
end
