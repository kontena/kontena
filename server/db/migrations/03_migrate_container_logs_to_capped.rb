class MigrateContainerLogsToCapped < Mongodb::Migration

  def self.up
    unless ContainerLog.collection.capped?
      ContainerLog.collection.session.command(
        convertToCapped: ContainerLog.collection.name,
        capped: true,
        size: 5.gigabytes
      )
    end
  end
end
