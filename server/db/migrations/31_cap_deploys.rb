class CapDeployCollections < Mongodb::Migration

  def self.up
    unless GridServiceDeploy.collection.capped?
      size = (ENV['DEPLOYS_CAPPED_SIZE'] || 24).to_i
      GridServiceDeploy.collection.client.command(
        convertToCapped: GridServiceDeploy.collection.name,
        capped: true,
        size: size.megabytes
      )
      GridServiceDeploy.create_indexes
    end

    unless StackDeploy.collection.capped?
      size = (ENV['DEPLOYS_CAPPED_SIZE'] || 24).to_i
      StackDeploy.collection.client.command(
        convertToCapped: StackDeploy.collection.name,
        capped: true,
        size: size.megabytes
      )
      StackDeploy.create_indexes
    end
  end
end
