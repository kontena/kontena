
class DistributedLockCleanupJob
  include Celluloid
  include Celluloid::Logger

  def perform
    DistributedLock.where(created_at: {:$lt => 5.minutes.ago}).destroy
  end
end