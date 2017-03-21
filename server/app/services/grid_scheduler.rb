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

  def reschedule
    self.reschedule_services
  end

  def reschedule_services
    grid.grid_services.each do |service|
      if should_reschedule_service?(service)
        reschedule_service(service)
      end
    end
  rescue => exc
    error exc.message
    debug exc.backtrace.join("\n") if exc.backtrace
  end

  def check_service(service)
    if should_reschedule_service?(service)
      reschedule_service(service)
    end
  end

  # @param [GridService] service
  # @return [Boolean]
  def should_reschedule_service?(service)
    return false unless service.running?
    return false if pending_deploys?(service)
    return false if active_deploys?(service)
    return false if active_deploys_within_stack?(service)

    if !all_instances_exist?(service)
      info "service #{service.to_path} has wrong number of instances (or they are not distributed correctly)"
      return true
    end
    if lagging_behind?(service)
      info "service #{service.to_path} does have older versions running"
      return true
    end

    if interval_passed?(service)
      info "service #{service.to_path} interval has passed"
      force_service_update(service)
      return true
    end

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
    available_nodes = service.grid.host_nodes.connected.to_a
    return true if available_nodes.size == 0

    current_nodes = service.grid_service_instances.map{ |c| c.host_node }.delete_if { |n| n.nil? }.uniq.sort
    service_deploy = GridServiceDeploy.new(grid_service: service)
    service_deployer = GridServiceDeployer.new(
      self.strategy(service.strategy), service_deploy, available_nodes
    )
    if service.stateless?
      return false if service_deployer.instance_count != service.grid_service_instances.count

      selected_nodes = service_deployer.selected_nodes.uniq.sort
      selected_nodes == current_nodes
    else
      service_deployer.instance_count == service.grid_service_instances.count
    end
  end

  # @param [GridService] service
  def reschedule_service(service)
    GridServiceDeploy.create(grid_service: service)
  end

  # @param [String] name
  def strategy(name)
    GridServiceScheduler::STRATEGIES[name].new
  end
end
