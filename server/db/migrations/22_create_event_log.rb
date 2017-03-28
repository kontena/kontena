class CreateEventLog < Mongodb::Migration

  def self.up
    unless EventLog.collection.capped?
      size = (ENV['EVENT_LOGS_CAPPED_SIZE'] || 100).to_i
      EventLog.collection.session.command(
        convertToCapped: EventLog.collection.name,
        capped: true,
        size: size.megabytes
      )
    end
    EventLog.create_indexes
  end
end
