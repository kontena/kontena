require_relative '../../spec_helper'

describe Metrics::HostNodeStatsMetrics do
  describe '#averge_cpu' do
    it 'calculates cpu values' do
      stats = []
      stats << HostNodeStat.new(created_at: Time.parse('2017-03-01 00:00:00'),
                                cpu_average: { system: 0.1, user: 0.2, idle: 0.7 })
      stats << HostNodeStat.new(created_at: Time.parse('2017-03-01 00:00:01'),
                                cpu_average: { system: 0.2, user: 0.3, idle: 0.5 })
      stats << HostNodeStat.new(created_at: Time.parse('2017-03-01 00:01:00'),
                                cpu_average: { system: 0.4, user: 0.5, idle: 0.1 })
      stats << HostNodeStat.new(created_at: Time.parse('2017-03-01 00:01:01'),
                                cpu_average: { system: 0.1, user: 0.9, idle: 0.9 })
      stats << HostNodeStat.new(created_at: Time.parse('2017-03-01 00:02:01'),
                                cpu_average: { system: 0.4, user: 0.5, idle: 0.1  })

      results = Metrics::HostNodeStatsMetrics.averge_cpu(stats)

      expect(results[:average]).to eq 0.72
      expect(results[:points].size).to eq 3
      expect(results[:points][0][:cpu]).to eq 0.4
      expect(results[:points][1][:cpu]).to eq 0.95
      expect(results[:points][2][:cpu]).to eq 0.9
    end
  end
end
