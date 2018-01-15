require_relative '../services/logging'

class DeploymentCleanupJob
  include Celluloid
  include CurrentLeader
  include Logging

  def initialize(perform = true)
    async.perform if perform
  end

  def perform
    info 'starting to cleanup old deployments'
    loop do
      sleep 5.minute.to_i
      if leader?
        destroy_old_deployments
      end
    end
  end

  def destroy_old_deployments
    GridService.each do |s|
      next if s.grid_service_deploys.finished.count <= 100
      info "cleaning old deployments for service #{s.to_path}"
      # Find the last 100th deployments id
      id = s.grid_service_deploys.finished.desc('_id').limit(100).to_a.last._id
      # Now delete all deployments older than the 100th one
      s.grid_service_deploys.finished.where(:_id.lt => id).delete
    end
  end
end
