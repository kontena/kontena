require 'celluloid'
require_relative '../services/logging'

class ContainerCleanupJob
  include Celluloid
  include DistributedLocks
  include Logging

  def initialize
    async.perform
  end

  def perform
    info 'starting to cleanup stale containers'
    loop do
      with_dlock('container_cleanup_job', 0) do
        Container.where(:updated_at.lt => 2.minutes.ago).each do |c|
          if c.host_node && c.host_node.connected?
            c.mark_for_delete
          elsif c.host_node.nil?
            c.destroy
          end
        end
        sleep 1.minute.to_i
      end
    end
  end
end
