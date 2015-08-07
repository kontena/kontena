
class NodeCleanupJob
  include SuckerPunch::Job
  include DistributedLocks

  def perform
    with_dlock('node_cleanup_job', 0) do
      HostNode.where(:updated_at.lt => 1.hour.ago).each do |node|
        unless node.connected?
          node.destroy
        end
      end
    end
  end
end
