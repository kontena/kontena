module Metrics
  class HostNodeStatMetrics
    def self.fetch(from_time, to_time)
      count = 0

      result = {
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
        filesystem_used_percent: 0.0
      }

      self.fetch_aggregates_from_mongo(from_time, to_time).each do |doc|
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
        result[:metrics] << {
          data_points: doc[:data_points],
          cpu_usage_percent: doc[:cpu_usage_percent].round(2),
          memory_used_bytes: doc[:memory_used_bytes],
          memory_total_bytes: doc[:memory_total_bytes],
          memory_used_percent: doc[:memory_used_percent].round(2),
          filesystem_used_bytes: doc[:filesystem_used_bytes],
          filesystem_total_bytes: doc[:filesystem_total_bytes],
          filesystem_used_percent: doc[:filesystem_used_percent].round(2),
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
      end

      result
    end

    def self.fetch_aggregates_from_mongo(from_time, to_time)
      HostNodeStat.collection.aggregate([
      {
        '$match': {
          created_at: {
            '$gte': from_time,
            '$lt': to_time
          }
        }
      },
      {
        '$sort': {
          created_at: -1
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
          data_points: 1
        }
      }
      ])
    end
  end
end
