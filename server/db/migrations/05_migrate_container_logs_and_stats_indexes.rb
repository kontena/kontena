class MigrateContainerLogsAndStatsIndexes < Mongodb::Migration

  def self.up
    ContainerLog.create_indexes
    ContainerStat.create_indexes
  end
end
