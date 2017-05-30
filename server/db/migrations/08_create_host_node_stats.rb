class CreateHostNodeStats < Mongodb::Migration

  def self.up
    unless HostNodeStat.collection.capped?
      HostNodeStat.collection.client.command(
        convertToCapped: HostNodeStat.collection.name,
        capped: true,
        size: 128.megabytes
      )
    end
    HostNodeStat.create_indexes
  end

end
