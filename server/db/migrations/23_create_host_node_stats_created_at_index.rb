class CreateHostNodeStatsCreatedAtIndex < Mongodb::Migration
  def self.up
    Thread.new {
      Thread.current.abort_on_exception = true
      HostNodeStat.create_indexes # might take a long time
    }
  end
end
