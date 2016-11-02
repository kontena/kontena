require 'celluloid'
require_relative '../services/logging'

class ContainerCleanupJob
  include Celluloid
  include CurrentLeader
  include Logging

  def initialize(perform = true)
    async.perform if perform
  end

  def perform
    info 'starting to cleanup stale containers'
    sleep 0.1
    loop do
      if leader?
        destroy_deleted_containers
      end
      sleep 1.minute.to_i
    end
  end

  def destroy_deleted_containers
    Container.deleted.where(:deleted_at.lt => 1.minutes.ago).each do |c|
      c.destroy
    end
  end
end
