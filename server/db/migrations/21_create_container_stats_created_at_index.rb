class CreateContainerStatsCreatedAtIndex < Mongodb::Migration
  def self.up
    ContainerStat.create_indexes
  end
end
