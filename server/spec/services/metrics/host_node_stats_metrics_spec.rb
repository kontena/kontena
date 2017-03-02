require_relative '../../spec_helper'

describe Metrics::HostNodeStatsMetrics do
  describe '#averge_cpu' do
    it 'calculates cpu values' do
      stats = [
        HostNodeStat.new(created_at: Time.parse('2017-03-01 00:00:00'), cpu_average: { system: 0.1, user: 0.2, idle: 0.7 }),
        HostNodeStat.new(created_at: Time.parse('2017-03-01 00:00:01'), cpu_average: { system: 0.2, user: 0.3, idle: 0.5 }),
        HostNodeStat.new(created_at: Time.parse('2017-03-01 00:01:00'), cpu_average: { system: 0.4, user: 0.5, idle: 0.1 }),
        HostNodeStat.new(created_at: Time.parse('2017-03-01 00:01:01'), cpu_average: { system: 0.1, user: 0.9, idle: 0.9 }),
        HostNodeStat.new(created_at: Time.parse('2017-03-01 00:02:01'), cpu_average: { system: 0.4, user: 0.5, idle: 0.1  })
      ]

      results = Metrics::HostNodeStatsMetrics.averge_cpu(stats)

      expect(results.aggregate).to eq 0.72
      expect(results.time_slices.size).to eq 3
      expect(results.time_slices[0].value).to eq 0.4
      expect(results.time_slices[1].value).to eq 0.95
      expect(results.time_slices[2].value).to eq 0.9
    end
  end
end
