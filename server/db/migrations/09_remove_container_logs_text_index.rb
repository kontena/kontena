class RemoveContainerLogsTextIndex < Mongodb::Migration

  def self.up
    ContainerLog.collection.indexes.drop_one(
      "_fts" => "text", "_ftsx" => 1
    )
  rescue Mongo::Error::OperationFailure
  end
end
