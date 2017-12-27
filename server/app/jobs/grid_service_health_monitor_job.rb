class GridServiceHealthMonitorJob
  include Celluloid
  include Logging
  include CurrentLeader

  PUBSUB_KEY = 'service:health_status_events'

  def initialize
    async.subscribe_health_events
  end

  def subscribe_health_events
    MasterPubsub.subscribe(PUBSUB_KEY) do |message|
      self.handle_event(message)
    end
  end

  def handle_event(event)
    return unless leader?
    service = GridService.find_by(id: event['id'])
    if deploy_needed?(service)
      info "service health too low, triggering full deploy for #{service.to_path}"
      GridServiceDeploy.create(grid_service: service)
    end
  end

  def deploy_needed?(service)
    health_status = service.health_status
    health_percent = health_status[:healthy].to_f / health_status[:total].to_f
    min_health = service.deploy_opts.min_health || 0.8
    expected_health = 1 - min_health
    if health_percent < expected_health
      service.running? && !service.deploying?
    else
      false
    end
  end

end
