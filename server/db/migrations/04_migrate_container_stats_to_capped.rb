class MigrateContainerStatsToCapped < Mongodb::Migration

  def self.up
    unless ContainerStat.collection.capped?
      ContainerStat.collection.session.command(
        convertToCapped: ContainerStat.collection.name,
        capped: true,
        size: 1.gigabyte
      )
    end
  end
end
