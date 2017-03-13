class AddIndexesToContainerLog < Mongodb::Migration
  def self.up
    ContainerLog.create_indexes
  end
end
