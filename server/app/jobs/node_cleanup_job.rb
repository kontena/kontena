require 'celluloid'
require_relative '../services/logging'

class NodeCleanupJob
  include Celluloid
  include Logging
  include DistributedLocks

  def initialize
    async.perform
  end

  def perform
    info 'starting to cleanup stale connections'
    every(1.minute.to_i) do
      cleanup_stale_connections
    end

    info 'starting to cleanup stale nodes'
    every(1.hour.to_i) do
      cleanup_stale_nodes
    end
  end

  def cleanup_stale_connections
    with_dlock('node_cleanup_job:stale_connections', 0) do
      HostNode.where(:last_seen_at.lt => 1.minute.ago).each do |node|
        node.set(connected: false)
      end
    end
  end

  def cleanup_stale_nodes
    with_dlock('node_cleanup_job:stale_nodes', 0) do
      HostNode.where(:last_seen_at.lt => 1.hour.ago).each do |node|
        unless node.connected?
          node.destroy
        end
      end
    end
  end
end
