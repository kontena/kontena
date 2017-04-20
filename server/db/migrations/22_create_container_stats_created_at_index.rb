class CreateContainerStatsCreatedAtIndex < Mongodb::Migration
  def self.up
    info "recreating container stat indexes, this might take long time"
    ContainerStat.create_indexes
  end
end
