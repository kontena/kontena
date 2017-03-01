require_relative '../services/logging'

class ServiceBalancerJob
  include Celluloid
  include Logging
  include CurrentLeader
  include Workers

  def initialize
    async.perform
  end

  def perform
    info 'starting to watch services'
    every(20) do
      if leader?
        balance_services
      end
    end
  end

  def balance_services
    GridService.order(updated_at: :asc).each do |service|
      begin
        fix_stale_deploy(service)
        balance_service(service) if should_balance_service?(service)
      rescue => exc
        error "error occurred in service #{service.to_path}"
        error exc.message
      end
    end
  end

  # @param [GridService] service
  def fix_stale_deploy(service)
    if service.deploying? && service.deployed_at && service.deployed_at < 5.minutes.ago
      info "service deploy seems stale, investigating: #{service.to_path}"
      unless deploy_alive?(service)
        info "deploy is stale, changing to running: #{service.to_path}"
        service.set(state: 'running')
      end
    end
  end

  # @param [GridService] service
  # @return [Boolean]
  def deploy_alive?(service)
    channel = "grid_service_deployer:#{service.id}"
    alive = false
    subscription = MongoPubsub.subscribe(channel) { |event|
      if event['event'].to_s == 'pong'
        info "service deploy is alive: #{service.to_path}"
        alive = true
      end
    }
    MongoPubsub.publish(channel, event: 'ping')
    sleep 0.1
    subscription.terminate

    alive
  rescue
    true
  end

  # @param [GridService] service
  # @return [Boolean]
  def should_balance_service?(service)
    return false unless service.running?

    if service.stateless?
      should_balance_stateless_service?(service)
    elsif service.stateful?
      should_balance_stateful_service?(service)
    end
  end

  # @param [GridService] service
  # @return [Boolean]
  def should_balance_stateless_service?(service)
    return false if pending_deploys?(service)
    return false if active_deploys?(service)
    return false if active_deploys_within_stack?(service)

    return true if !all_instances_exist?(service)
    return true if lagging_behind?(service)

    if interval_passed?(service)
      force_service_update(service)
      return true
    end

    false
  end

  # @param [GridService] service
  # @return [Boolean]
  def should_balance_stateful_service?(service)
    false
  end

  # @param [GridService] service
  # @return [Boolean]
  def pending_deploys?(service)
    service.grid_service_deploys.where(started_at: nil).count > 0
  end

  # @param [GridService] service
  # @return [Boolean]
  def active_deploys?(service)
    service.grid_service_deploys.where(:started_at.gt => 30.minutes.ago, :deploy_state.in => [:created, :ongoing]).count > 0
  end

  # @param [GridService] service
  # @return [Boolean]
  def active_deploys_within_stack?(service)
    service.stack.stack_deploys.where(:created_at.gt => 30.minutes.ago, :deploy_state.in => [:created, :ongoing]).count > 0
  end

  # @param [GridService] service
  # @return [Boolean]
  def lagging_behind?(service)
    return true if service.deployed_at && service.updated_at > service.deployed_at

    false
  end

  # @param [GridService] service
  # @return [Boolean]
  def interval_passed?(service)
    if deploy_interval = service.deploy_opts.interval
      if (service.deployed_at.to_i + deploy_interval.to_i) < Time.now.to_i
        return true
      end
    end

    false
  end

  # @param [GridService] service
  def force_service_update(service)
    service.set(updated_at: Time.now)
  end

  # @param [GridService] service
  # @return [Boolean]
  def all_instances_exist?(service)
    desired_count = desired_count_for_service(service)
    running_count = service.containers.where(:'state.running' => true).count

    return true if running_count == desired_count

    offline_count = service.containers.unscoped.where(
      :'state.running' => true,
      :deleted_at.gt => grace_period_for_service(service).ago
    ).count
    return false if offline_count == 0

    (running_count + offline_count) >= desired_count
  end

  # @param [GridService] service
  # @return [Fixnum]
  def desired_count_for_service(service)
    return 0 unless service.grid

    if service.daemon?
      (service.container_count * service.grid.host_nodes.connected.count)
    else
      service.container_count
    end
  end

  # @param [GridService] service
  # @return [ActiveSupport::Duration]
  def grace_period_for_service(service)
    if service.daemon?
      3.minutes
    else
      1.minute
    end
  end

  # @param [GridService] service
  def balance_service(service)
    info "rebalancing service: #{service.to_path}"
    GridServiceDeploy.create(grid_service: service)
  end
end
