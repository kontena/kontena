class AddIndexesToContainerLog < Mongodb::Migration
  def self.up
    Thread.new {
      Thread.current.abort_on_exception = true
      ContainerLog.create_indexes # might take a long time
    }
  end
end
