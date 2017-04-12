require_relative '../services/logging'

class DistributedLockCleanupJob
  include Celluloid
  include Logging
  include DistributedLocks

  def initialize
    async.perform
  end

  def perform
    info 'starting to cleanup stale locks'
    loop do
      DistributedLock.where(created_at: {:$lt => 5.minutes.ago}).delete
      sleep 5.minutes.to_i
    end
  end
end
