class GridStat
  include Mongoid::Document
  include Mongoid::Timestamps

  field :running_containers, type: Integer
  field :not_running_containers, type: Integer
  belongs_to :grid

  index({ grid_id: 1 })
  index({ created_at: 1 })

  ##
  # @param [BSON::ObjectId] grid_id
  # @param [Time] start_time
  # @param [Time] end_time
  def self.container_count(grid_id, start_time, end_time)
    self.collection.aggregate([
      {
          '$match' => {
              'grid_id' => grid_id,
              '$and' => [
                  { 'created_at' => { '$gte' => start_time } },
                  { 'created_at' => { '$lte'=> end_time }}
              ]
          }
      },
      {
          '$group' => {
              '_id' => {
                  'year' => {'$year' => '$created_at'},
                  'month' => {'$month' => '$created_at'},
                  'day' => {'$dayOfMonth' => '$created_at'},
                  'hour' => {'$hour' => '$created_at'},
                  'minute' => {'$minute' => '$created_at'},

              },
              'running' => {
                  '$avg' => '$running_containers'
              },
              'not_running' => {
                  '$avg' => '$not_running_containers'
              }
          }
      },
      {
          '$sort' => {'_id' => 1}
      }
    ])
  end

  ##
  # @param [BSON::ObjectId] grid_id
  # @param [Time] start_time
  # @param [Time] end_time
  def self.memory_usage(grid_id, start_time, end_time)
    ContainerStat.collection.aggregate(
        [
          self.filter_for_grid(grid_id, start_time, end_time),
          {
              '$group' => {
                  '_id' => {
                      'container_id' => '$container_id',
                      'year' => {'$year' => '$created_at'},
                      'month' => {'$month' => '$created_at'},
                      'day' => {'$dayOfMonth' => '$created_at'},
                      'hour' => {'$hour' => '$created_at'},
                      'minute' => {'$minute' => '$created_at'}
                  },
                  'memory' => {
                      '$avg' => '$memory.usage'
                  }
              }
          },
          {
              '$group' => {
                  '_id' => {
                      'year' => '$_id.year',
                      'month' => '$_id.month',
                      'day' => '$_id.day',
                      'hour' => '$_id.hour',
                      'minute' => '$_id.minute'
                  },
                  'memory' => {
                      '$sum' => '$memory'
                  }

              }
          },
          {
              '$sort' => {'_id' => 1}
          }
      ]
    )
  end

  ##
  # @param [BSON::ObjectId] grid_id
  # @param [Time] start_time
  # @param [Time] end_time
  def self.cpu_usage(grid_id, start_time, end_time)
    ContainerStat.collection.aggregate(
        [
            self.filter_for_grid(grid_id, start_time, end_time),
            {
                '$group' => {
                    '_id' => {
                        'container_id' => '$container_id',
                        'year' => {'$year' => '$created_at'},
                        'month' => {'$month' => '$created_at'},
                        'day' => {'$dayOfMonth' => '$created_at'},
                        'hour' => {'$hour' => '$created_at'},
                        'minute' => {'$minute' => '$created_at'}
                    },
                    'cpu' => {
                        '$avg' => '$cpu.usage_pct'
                    }
                }
            },
            {
                '$group' => {
                    '_id' => {
                        'year' => '$_id.year',
                        'month' => '$_id.month',
                        'day' => '$_id.day',
                        'hour' => '$_id.hour',
                        'minute' => '$_id.minute'
                    },
                    'cpu' => {
                        '$avg' => '$cpu'
                    }

                }
            },
            {
                '$sort' => {'_id' => 1}
            }
        ]
    )
  end

  ##
  # @param [BSON::ObjectId] grid_id
  # @param [Time] start_time
  # @param [Time] end_time
  def self.filesystem_usage(grid_id, start_time, end_time)
    ContainerStat.collection.aggregate(
        [
            self.filter_for_grid(grid_id, start_time, end_time),
            {
                '$group' => {
                    '_id' => {
                        'container_id' => '$container_id',
                        'year' => {'$year' => '$created_at'},
                        'month' => {'$month' => '$created_at'},
                        'day' => {'$dayOfMonth' => '$created_at'},
                        'hour' => {'$hour' => '$created_at'},
                        'minute' => {'$minute' => '$created_at'}
                    },
                    'filesystem' => {
                        '$avg' => '$filesystem.usage'
                    }
                }
            },
            {
                '$group' => {
                    '_id' => {
                        'year' => '$_id.year',
                        'month' => '$_id.month',
                        'day' => '$_id.day',
                        'hour' => '$_id.hour',
                        'minute' => '$_id.minute'
                    },
                    'filesystem' => {
                        '$sum' => '$filesystem'
                    }

                }
            },
            {
                '$sort' => {'_id' => 1}
            }
        ]
    )
  end

  private

  ##
  # @param [BSON::ObjectId] grid_id
  # @param [Time] start_time
  # @param [Time] end_time
  def self.filter_for_grid(grid_id, start_time, end_time)
    {
        '$match' => {
            'grid_id' => grid_id,
            '$and' => [
                { 'created_at' => { '$gte' => start_time } },
                {'created_at' => { '$lte'=> end_time }}
            ]
        }
    }
  end
end