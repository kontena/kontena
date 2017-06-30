class Metrics

  # @param [Mongo::Collection] containers_collection
  # @param [Symbol] sort
  # @param [Integer] limit
  def self.get_container_stats(containers_collection, sort, limit)
    containers = containers_collection.where(
      :container_id => {:$ne => nil}, 'state.running' => true
    ).asc(:created_at)

    results = containers.map { |container|
      {
          container: container,
          stats: container.container_stats.latest
      }
    }.sort_by { |stat|
      num = 0

      if stat[:stats]
        case sort
        when :memory
          num = stat[:stats].memory['usage']
        when :rx_bytes
          num = (stat[:stats].network['internal']['rx_bytes'] + stat[:stats].network['external']['rx_bytes'])
        when :tx_bytes
          num = (stat[:stats].network['internal']['tx_bytes'] + stat[:stats].network['external']['tx_bytes'])
        else
          num = stat[:stats].cpu['usage_pct']
        end
      end

      num
    }.reverse

    results = results.take(limit) if (limit)
    results
  end
end
