
class ContainerCleanupJob
  include SuckerPunch::Job
  include FistOfFury::Recurrent

  recurs { minutely }

  def perform
    puts 'ASDASDASDASD'
    Container.where(:updated_at.lt => 2.minutes.ago).each do |c|
      if c.host_node && c.host_node.connected?
        c.mark_for_delete
      elsif c.host_node.nil?
        c.destroy
      end
    end
  end
end