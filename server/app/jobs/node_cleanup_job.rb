require_relative '../services/logging'

class NodeCleanupJob
  include Celluloid
  include Logging
  include CurrentLeader

  NODE_DISCONNECT_TIMEOUT = 1.minute
  NODE_DESTROY_TIMEOUT = 6.hours

  def initialize
    async.perform
  end

  def perform
    info 'starting to cleanup stale connections'
    every(1.minute.to_i) do
      cleanup_stale_connections if leader?
    end

    info 'starting to cleanup stale nodes'
    every(1.hour.to_i) do
      cleanup_stale_nodes if leader?
    end
  end

  def cleanup_stale_connections
    HostNode.where(:last_seen_at.lt => NODE_DISCONNECT_TIMEOUT.ago).each do |node|
      node.set(connected: false)
      deleted_at = Time.now.utc
      node.containers.each do |c|
        c.with(safe: false).set(:deleted_at => deleted_at) unless c.deleted_at
      end
    end
  end

  def cleanup_stale_nodes
    HostNode.where(:last_seen_at.lt => NODE_DESTROY_TIMEOUT.ago).each do |node|
      if !node.grid.initial_node?(node) && !node.connected? && !node.stateful? && node.ephemeral?
        warn "Destroying disconnected ephemeral node #{node.to_path}"

        node.destroy
      end
    end
  end
end
