
class DistributedLockCleanupJob
  include Celluloid
  include Celluloid::Logger
  include DistributedLocks

  def initialize
    async.perform
  end

  def perform
    loop do
      info 'DistributedLockCleanupJob: starting to cleanup stale locks'
      DistributedLock.where(created_at: {:$lt => 5.minutes.ago}).destroy
      sleep 5.minutes.to_i
    end
  end
end
