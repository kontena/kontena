module EventStream
  extend ActiveSupport::Concern
  CHANNEL = "FirehoseApiEvent".freeze

  included do
    after_create :publish_create_event
    after_update :publish_update_event
    after_destroy :publish_destroy_event
  end

  def self.channel
    CHANNEL
  end

  def publish_create_event
    event = {
      event: 'create',
      type: self.class.name,
      object: find_serializer.to_hash
    }
    publish_async(event)
  end

  def publish_update_event(relation_object = nil)
    event = {
      event: 'update',
      type: self.class.name,
      object: find_serializer.to_hash
    }
    publish_async(event)
  end

  def publish_destroy_event
    event = {
      event: 'delete',
      type: self.class.name,
      object: find_serializer.to_hash
    }
    publish_async(event)
  end

  def publish_async(event)
    MasterPubsub.publish_async(CHANNEL, event) if MasterPubsub.started?
  end

  def find_serializer_class
    class_name = "#{self.class.name}Serializer"
    class_name.constantize
  end

  def find_serializer
    find_serializer_class.new(self)
  end
end
