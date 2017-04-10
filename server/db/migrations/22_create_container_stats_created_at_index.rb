class CreateContainerStatsCreatedAtIndex < Mongodb::Migration
  def self.up
    Thread.new { ContainerStat.create_indexes } # might take a long time
  end
end
