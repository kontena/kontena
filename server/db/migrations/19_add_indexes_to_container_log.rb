class AddIndexesToContainerLog < Mongodb::Migration
  def self.up
    info "recreating container log indexes, this might take long time"
    ContainerLog.create_indexes
  end
end
