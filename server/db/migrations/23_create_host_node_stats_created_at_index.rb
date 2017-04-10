class CreateHostNodeStatsCreatedAtIndex < Mongodb::Migration
  def self.up
    Thread.new { HostNodeStat.create_indexes }
  end
end
