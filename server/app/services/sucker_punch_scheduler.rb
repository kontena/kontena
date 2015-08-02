class SuckerPunchScheduler
  include Celluloid
  include Celluloid::Logger
  include DistributedLocks

  def initialize
    @timers = []
    async.schedule!
  end

  def schedule!
    CollectionIndexerJob.new.async.perform

    @timers << every(1.minute.to_i) do
      with_dlock('container_cleanup_job', 0) {
        info 'starting ContainerCleanupJob'
        ContainerCleanupJob.new.async.perform
      }
    end
    @timers << every(5.minute.to_i) do
      with_dlock('distributed_lock_cleanup', 0) {
        info 'starting ContainerCleanupJob'
        DistributedLockCleanupJob.new.async.perform
      }
    end
    @timers << every(1.hour.to_i) do
      with_dlock('node_cleanup_job', 0) {
        info 'starting NodeCleanupJob'
        NodeCleanupJob.new.async.perform
      }
    end

    @timers
  end
end
