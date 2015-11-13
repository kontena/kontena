require_relative 'high_availability'

module Scheduler
  module Strategy
    class Daemon < Strategy::HighAvailability

      # @param [Integer] node_count
      # @param [Integer] instance_count
      def instance_count(node_count, instance_count)
        node_count.to_i * instance_count.to_i
      end
    end
  end
end
