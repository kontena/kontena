class CreateHostNodeStatsCreatedAtIndex < Mongodb::Migration
  def self.up
    info "recreating node stat indexes, this might take long time"
    HostNodeStat.create_indexes
  end
end
