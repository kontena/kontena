class ServiceDeployQueuedAt < Mongodb::Migration
  def self.up
    GridServiceDeploy.create_indexes
    GridServiceDeploy.all.set(queued_at: Time.now.utc)
  end
end
