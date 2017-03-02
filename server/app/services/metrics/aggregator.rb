require 'rounding'

module Metrics
  class Aggregator

    # @param [Array<Metric>] metrics
    # @param [Number] seconds_of_granularity
    # @return [Aggregates]
    def self.average(metrics, seconds_of_granularity = 60)
      time_slices = {}
      total_metrics = 0
      total_value = 0.0

      metrics.each do |metric|
        total_metrics += 1
        total_value += metric.value
        time_slice = metric.created_at.floor_to(seconds_of_granularity)

        if time_slices[time_slice]
          time_slices[time_slice] << metric.value
        else
          time_slices[time_slice] = [metric.value]
        end
      end

      avg = total_value / total_metrics.to_f
      avg_time_slices = time_slices.keys.sort.map do |time_slice|
        avg_for_slice = time_slices[time_slice].reduce(:+) / time_slices[time_slice].size.to_f
        Metric.new(time_slice, avg_for_slice)
      end

      Aggregates.new(avg, avg_time_slices)
    end
  end
end
