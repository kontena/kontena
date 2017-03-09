module Metrics
  class HostNodeMetrics
      # @param [String] node_id
      # @param [Time] from_time
      # @param [Time] to_time
      # @return [Hash] the aggregation results
    def self.fetch(node_id, from_time, to_time)
      stats = HostNodeStat.get_aggregate_stats_for_node(node_id, from_time, to_time).map do |doc|
        ts = doc[:timestamp]

        {
          data_points: doc[:data_points],
          cpu_usage_percent: doc[:cpu_usage_percent].round(2),
          memory_used_bytes: doc[:memory_used_bytes],
          memory_total_bytes: doc[:memory_total_bytes],
          memory_used_percent: doc[:memory_used_percent].round(2),
          filesystem_used_bytes: doc[:filesystem_used_bytes],
          filesystem_total_bytes: doc[:filesystem_total_bytes],
          filesystem_used_percent: doc[:filesystem_used_percent].round(2),
          network_in_bytes_per_second: doc[:network_in_bytes_per_second],
          network_out_bytes_per_second: doc[:network_out_bytes_per_second],
          timestamp: Time.new(ts[:year], ts[:month], ts[:day], ts[:hour], ts[:minute], 0, "+00:00")
        }
      end

      {
        from_time: from_time,
        to_time: to_time,
        stats: stats
      }
    end
  end
end
