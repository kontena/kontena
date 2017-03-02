require 'rounding'

module Metrics
  class HostNodeStatsMetrics

    # @param [Array<HostNodeStat>] host_node_stats
    # @param [Number] seconds_of_granularity
    # @return [Array<Hash>]
    def self.averge_cpu(host_node_stats, seconds_of_granularity = 60)
      metrics = host_node_stats.map do |stat|
        cpu = stat.cpu_average[:system] + stat.cpu_average[:user]
        Metric.new(stat.created_at, cpu)
      end

      return Aggregator.average(metrics, seconds_of_granularity)
    end
  end
end
