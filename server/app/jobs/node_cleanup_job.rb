
class NodeCleanupJob
  include SuckerPunch::Job
  include FistOfFury::Recurrent

  recurs { hourly }

  def perform
    HostNode.where(:updated_at.lt => 1.hour.ago).each do |node|
      unless node.connected?
        node.destroy
      end
    end
  end
end
