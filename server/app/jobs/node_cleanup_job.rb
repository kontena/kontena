
class NodeCleanupJob
  include Celluloid
  include Celluloid::Logger
  include DistributedLocks

  def initialize
    async.perform
  end

  def perform
    every(1.minute.to_i) do
      cleanup_stale_connections
    end
    every(1.hour.to_i) do
      cleanup_stale_nodes
    end
  end

  def cleanup_stale_connections
    with_dlock('node_cleanup_job:stale_connections', 0) do
      info 'NodeCleanupJob: starting to cleanup stale connections'
      HostNode.where(:last_seen_at.lt => 1.minute.ago).each do |node|
        node.set(connected: false)
      end
    end
  end

  def cleanup_stale_nodes
    with_dlock('node_cleanup_job:stale_nodes', 0) do
      info 'NodeCleanupJob: starting to cleanup stale nodes'
      HostNode.where(:updated_at.lt => 1.hour.ago).each do |node|
        unless node.connected?
          node.destroy
        end
      end
    end
  end
end
