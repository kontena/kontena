class AddIndexesToContainerLog < Mongodb::Migration
  def self.up
    Thread.new { ContainerLog.create_indexes } # might take a long time
  end
end
