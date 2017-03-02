require 'rounding'

module Metrics
  class HostNodeStatsMetrics

    # @param [Array<HostNodeStat>] host_node_stats
    # @param [Number] seconds_of_granularity
    # @return [Array<Hash>]
    def self.averge_cpu(host_node_stats, seconds_of_granularity = 60)
      total_stats = 0
      total_cpu = 0.0
      buckets = {}

      host_node_stats.each do |stat|
        cpu = stat.cpu_average[:system] + stat.cpu_average[:user]
        total_stats += 1
        total_cpu += cpu
        bucket = stat.created_at.floor_to(seconds_of_granularity)

        if buckets[bucket]
          buckets[bucket] << cpu
        else
          buckets[bucket] = [cpu]
        end
      end

      return {
        average: total_cpu / total_stats.to_f,
        points: buckets.map { |k, v| { time: k, cpu: v.reduce(:+) / v.size.to_f }  }
      }
    end
  end
end
