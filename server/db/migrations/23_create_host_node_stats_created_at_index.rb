class CreateHostNodeStatsCreatedAtIndex < Mongodb::Migration
  def self.up
    info "recreating node stat indexes, this might take a log time"
    HostNodeStat.create_indexes
  end
end
