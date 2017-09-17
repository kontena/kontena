require_relative '../services/logging'

class LeaderElectorJob
  include Celluloid
  include Logging
  include DistributedLocks

  DLOCK_KEY = 'leader_elect'
  PUBSUB_KEY = 'master:leader_elect'

  def initialize
    @leader = false
    async.perform
  end

  def perform
    info 'participating leader elections'
    self.listen_events
    self.cleanup
    self.elect
    every(10) do
      self.elect unless leader?
      self.cleanup
    end
  end

  # Fastest master to acquire lock wins
  def elect
    with_dlock(DLOCK_KEY, nil) do
      info "won election ♚" unless @was_leader
      promote
      sleep 58
    end
    if leader?
      @was_leader = true
      step_down
      announce_election
    else
      @was_leader = false
    end
  end

  def announce_election
    self.elect
    MasterPubsub.publish(PUBSUB_KEY, {})
  end

  def listen_events
    MasterPubsub.subscribe(PUBSUB_KEY) do |event|
      self.elect
    end
  end

  def cleanup
    DistributedLock.where(
      name: DLOCK_KEY,
      created_at: {:$lt => 1.minute.ago}
    ).destroy
  end

  def leader?
    @leader
  end

  def step_down
    @leader = false
  end

  def promote
    @leader = true
  end
end
