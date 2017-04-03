class CreateHostNodeStatsCreatedAtIndex < Mongodb::Migration
  def self.up
    HostNodeStat.create_indexes
  end
end
