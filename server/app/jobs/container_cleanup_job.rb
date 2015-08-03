
class ContainerCleanupJob
  include SuckerPunch::Job
  include DistributedLocks

  def perform
    with_dlock('container_cleanup_job', 0) do
      Container.where(:updated_at.lt => 2.minutes.ago).each do |c|
        if c.host_node && c.host_node.connected?
          c.mark_for_delete
        elsif c.host_node.nil?
          c.destroy
        end
      end
    end
  end
end
