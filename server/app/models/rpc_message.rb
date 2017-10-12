class RpcMessage
  include Mongoid::Document

  field :created_at, type: DateTime
  field :data, type: BSON::Binary

  def ensure_capped!
    unless self.collection.client.database.collection_names.include?(self.collection.name)
      self.collection.client.command(create: self.collection.name)
    end
    unless self.collection.capped?
      self.collection.client.command(
        convertToCapped: self.collection.name,
        capped: true,
        size: 24.megabytes
      )
      self.publish('test', {})
    end
  end
end