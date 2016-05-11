class RemoveContainerLogsTextIndex < Mongodb::Migration

  def self.up
    ContainerLog.collection.indexes.drop(
      "_fts" => "text", "_ftsx" => 1
    )
  end
end
