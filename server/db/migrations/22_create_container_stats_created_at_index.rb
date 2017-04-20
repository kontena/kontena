class CreateContainerStatsCreatedAtIndex < Mongodb::Migration
  def self.up
    info "recreating container stat indexes, this might take a log time"
    ContainerStat.create_indexes
  end
end
