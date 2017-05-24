class MigrateContainerStatsToCapped < Mongodb::Migration

  def self.up
    unless ContainerStat.collection.capped?
      size = (ENV['CONTAINER_STATS_CAPPED_SIZE'] || 500).to_i
      ContainerStat.collection.client.command(
        convertToCapped: ContainerStat.collection.name,
        capped: true,
        size: size.megabytes
      )
    end
  end
end
