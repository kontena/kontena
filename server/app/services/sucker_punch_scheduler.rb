class SuckerPunchScheduler
  include Celluloid
  include Celluloid::Logger

  def initialize
    @timers = []
    async.schedule!
  end

  def schedule!
    CollectionIndexerJob.new.async.perform

    @timers << every(1.minute.to_i) do
      info 'starting ContainerCleanupJob'
      ContainerCleanupJob.new.async.perform
    end
    @timers << every(5.minute.to_i) do
      info 'starting ContainerCleanupJob'
      DistributedLockCleanupJob.new.async.perform
    end
    @timers << every(1.hour.to_i) do
      info 'starting NodeCleanupJob'
      NodeCleanupJob.new.async.perform
    end

    @timers
  end
end
