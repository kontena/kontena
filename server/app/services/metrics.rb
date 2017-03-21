class Metrics

  # @param [Container Mongo Collection] containers_collection
  # @param [String] network_iface
  # @param [Symbol] sort
  def self.get_container_stats(containers_collection, network_iface, sort)
    containers = containers_collection.where(container_id: {:$ne => nil}).asc(:created_at)

    containers.map { |container|
      stat = container.container_stats.last
      stat.update_network_stats(network_iface) if stat
      {
          container: container,
          stats: stat
      }
    }.sort_by { |stat|
      num = 0

      if stat[:stats]
        case sort
        when :memory
          num = stat[:stats].memory['usage']
        when :rx_bytes
          num = stat[:stats].network['rx_bytes']
        when :tx_bytes
          num = stat[:stats].network['tx_bytes']
        else
          num = stat[:stats].cpu['usage_pct']
        end
      end

      num
    }.reverse
  end
end
