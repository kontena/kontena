require 'celluloid'
require_relative '../services/logging'

class ContainerCleanupJob
  include Celluloid
  include DistributedLocks
  include Logging

  def initialize(perform = true)
    async.perform if perform
  end

  def perform
    info 'starting to cleanup stale containers'
    loop do
      with_dlock('container_cleanup_job', 0) do
        cleanup_stale_containers
        destroy_deleted_containers

        sleep 1.minute.to_i
      end
    end
  end

  def cleanup_stale_containers
    Container.where(:updated_at.lt => 2.minutes.ago).each do |c|
      if c.host_node && c.host_node.connected?
        c.mark_for_delete
      elsif c.host_node.nil?
        c.destroy
      end
    end
  end

  def destroy_deleted_containers
    Container.deleted.where(:deleted_at.lt => 1.minutes.ago).each do |c|
      c.destroy
    end
  end
end
