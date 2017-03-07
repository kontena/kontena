module Metrics
  class HostNodeStatMetrics
      # @param [String] node_id
      # @param [Time] from_time
      # @param [Time] to_time
      # @return [Hash] the aggregation results
    def self.fetch_for_node(node_id, from_time, to_time)
      self.fetch_aggregates(node_id, nil, from_time, to_time)
    end

    # @param [String] grid_id
    # @param [Time] from_time
    # @param [Time] to_time
    # @return [Hash] the aggregation results
    def self.fetch_for_grid(grid_id, from_time, to_time)
      self.fetch_aggregates(nil, grid_id, from_time, to_time)
    end

    private

    def self.fetch_aggregates(node_id, grid_id, from_time, to_time)
      count = 0

      result = {
        node_id: node_id,
        from_time: from_time,
        to_time: to_time,
        metrics: [],
        data_points: 0,
        cpu_usage_percent: 0.0,
        memory_used_bytes: 0,
        memory_total_bytes: 0,
        memory_used_percent: 0.0,
        filesystem_used_bytes: 0,
        filesystem_total_bytes: 0,
        filesystem_used_percent: 0.0,
        network_in_bytes_per_second: 0,
        network_out_bytes_per_second: 0
      }

      self.fetch_aggregates_from_mongo(node_id, grid_id, from_time, to_time).each do |doc|
        count += 1
        ts = doc[:timestamp]
        result[:data_points] += doc[:data_points]
        result[:cpu_usage_percent] += doc[:cpu_usage_percent]
        result[:memory_used_bytes] += doc[:memory_used_bytes]
        result[:memory_total_bytes] += doc[:memory_total_bytes]
        result[:memory_used_percent] += doc[:memory_used_percent]
        result[:filesystem_used_bytes] += doc[:filesystem_used_bytes]
        result[:filesystem_total_bytes] += doc[:filesystem_total_bytes]
        result[:filesystem_used_percent] += doc[:filesystem_used_percent]
        result[:network_in_bytes_per_second] += doc[:network_in_bytes_per_second]
        result[:network_out_bytes_per_second] += doc[:network_out_bytes_per_second]
        result[:metrics] << {
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

      if (count > 1)
        result[:cpu_usage_percent] = (result[:cpu_usage_percent] / count.to_f).round(2)
        result[:memory_used_bytes] /= count
        result[:memory_total_bytes] /= count
        result[:memory_used_percent] = (result[:memory_used_percent] / count.to_f).round(2)
        result[:filesystem_used_bytes] /= count
        result[:filesystem_total_bytes] /= count
        result[:filesystem_used_percent] = (result[:filesystem_used_percent] / count.to_f).round(2)
        result[:network_in_bytes_per_second] /= count
        result[:network_out_bytes_per_second] /= count
      end

      result
    end

    def self.fetch_aggregates_from_mongo(node_id, grid_id, from_time, to_time)
      match = {
        created_at: {
          '$gte': from_time,
          '$lt': to_time
        }
      }

      if (node_id)
        match[:host_node_id] = node_id
      else
        match[:grid_id] = grid_id
      end

      HostNodeStat.collection.aggregate([
      {
        '$match': match
      },
      {
        '$sort': {
          created_at: 1
        }
      },
      {
        '$unwind': '$filesystem',
      },
      {
        '$project': {
          _id: 1,
          created_at: 1,
          cpu_average: {
            system: 1,
            user: 1
          },
          memory: {
            total: 1,
            used: 1
          },
          filesystem: {
            total: 1,
            used: 1
          },
          network: {
            in_bytes_per_second: 1,
            out_bytes_per_second: 1
          }
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
          },
          cpu_usage_percent: {
            '$avg': { '$add': ['$cpu_average.user', '$cpu_average.system'] }
          },
          memory_used_bytes: {
            '$avg': '$memory.used'
          },
          memory_total_bytes: {
            '$avg': '$memory.total'
          },
          memory_used_percent: {
            '$avg': { '$divide': ['$memory.used', '$memory.total'] }
          },
          filesystem_used_bytes: {
            '$avg': '$filesystem.used'
          },
          filesystem_total_bytes: {
            '$avg': '$filesystem.total'
          },
          filesystem_used_percent: {
            '$avg': { '$divide': ['$filesystem.used', '$filesystem.total'] }
          },
          network_in_bytes_per_second: {
            '$avg': '$network.in_bytes_per_second'
          },
          network_out_bytes_per_second: {
            '$avg': '$network.out_bytes_per_second'
          },
          max_timestamp: {
            '$max': '$created_at'
          },
          data_points: { '$sum': 1 }
        }
      },
      {
        '$sort': { max_timestamp: 1 }
      },
      {
        '$project': {
          _id: 0,
          timestamp: '$_id',
          cpu_usage_percent: 1,
          memory_used_bytes: 1,
          memory_total_bytes: 1,
          memory_used_percent: 1,
          filesystem_used_bytes: 1,
          filesystem_total_bytes: 1,
          filesystem_used_percent: 1,
          network_in_bytes_per_second: 1,
          network_out_bytes_per_second: 1,
          data_points: 1
        }
      }
      ])
    end
  end
end
