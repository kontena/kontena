require_relative 'grid_service_deployer'
require_relative '../mutations/grid_services/deploy'
require_relative 'logging'

class GridScheduler
  include Logging
  include Workers

  attr_reader :grid

  # @param [Grid] grid
  def initialize(grid)
    @grid = grid
  end

  def check_service(service)
    if should_reschedule_service?(service)
      reschedule_service(service)
    end
  end

  # @param [GridService] service
  # @return [Boolean]
  def should_reschedule_service?(service)
    return false if service.stateful?
    return false unless service.running?
    return false if service.deploying?
    return false if active_deploys_within_stack?(service)

    if !all_instances_exist?(service)
      info "service #{service.to_path} has wrong number of instances (or they are not distributed correctly)"
      log_service_event(service, "service #{service.to_path} has wrong number of instances (or they are not distributed correctly)")
      return true
    end

    if lagging_behind?(service)
      info "service #{service.to_path} does have older versions running"
      log_service_event(service, "service #{service.to_path} does have older version running")
      return true
    end

    if interval_passed?(service)
      info "service #{service.to_path} interval has passed"
      log_service_event(service, "service #{service.to_path} deploy interval has passed")
      force_service_update(service)
      return true
    end

    false
  end

  # @param [GridService] service
  # @return [Boolean]
  def active_deploys_within_stack?(service)
    service.stack.stack_deploys.where(:created_at.gt => 30.minutes.ago, :_deploy_state.in => [:created, :ongoing]).count > 0
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
    available_nodes = service.grid.host_nodes.connected.to_a
    return true if available_nodes.size == 0

    strategy = self.strategy(service.strategy)
    service_instances = service.grid_service_instances.includes(:host_node).to_a
    current_nodes = service_instances.map{ |c| c.host_node }.compact.uniq.sort
    offline_within_grace_period = current_nodes.select { |n|
      !n.connected? && n.last_seen_at && n.last_seen_at > strategy.host_grace_period.ago
    }
    available_nodes = (available_nodes + offline_within_grace_period).uniq

    service_deploy = GridServiceDeploy.new(grid_service: service)
    service_deployer = GridServiceDeployer.new(
      strategy, service_deploy, available_nodes
    )
    return false if service_deployer.instance_count != service_instances.map{ |c| c.host_node }.compact.size

    selected_nodes = service_deployer.selected_nodes.uniq.sort
    selected_nodes == current_nodes
  end

  # @param [GridService] service
  def reschedule_service(service)
    info "rescheduling service #{service.to_path}"
    GridServiceDeploy.create(grid_service: service)
  end

  # @param [String] name
  def strategy(name)
    GridServiceScheduler::STRATEGIES[name].new
  end

  # @param [GridService] service
  # @param [String] msg
  def log_service_event(service, msg, severity = EventLog::INFO)
    EventLog.create(
      msg: msg,
      severity: severity,
      type: 'scheduler',
      grid_service_id: service.id,
      grid_id: service.grid_id
    )
  end
end
