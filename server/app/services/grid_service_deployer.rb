require_relative 'logging'
require_relative 'grid_service_scheduler'
require_relative 'scheduler/node'

class GridServiceDeployer
  include Logging

  DeployError = Class.new(StandardError)

  attr_reader :grid_service_deploy,
              :grid_service,
              :nodes,
              :scheduler

  ##
  # @param [#find_node] strategy
  # @param [GridServiceDeploy] grid_service_deploy
  # @param [Array<HostNode>] nodes
  def initialize(strategy, grid_service_deploy, nodes)
    @grid_service_deploy = grid_service_deploy
    @scheduler = GridServiceScheduler.new(strategy)
    @grid_service = grid_service_deploy.grid_service
    @nodes = nodes.map { |n| Scheduler::Node.new(n) }
  end

  # @return [Array<HostNode>]
  def selected_nodes
    count = self.instance_count
    available_nodes = self.nodes.map { |n| n.clone }
    nodes = []
    count.times do |i|
      begin
        nodes << self.scheduler.select_node(
          self.grid_service, i + 1, available_nodes
        )
      rescue Scheduler::Error

      end
    end

    nodes.map { |n| n.node }
  end

  def deploy
    info "starting to deploy #{self.grid_service.to_path}"
    log_service_event("service #{self.grid_service.to_path} deploy started")
    self.grid_service_deploy.set(:_deploy_state => :ongoing)
    deploy_rev = Time.now.utc.to_s
    self.grid_service.set(:deployed_at => deploy_rev)

    deploy_futures = []
    total_instances = self.instance_count
    self.grid_service.grid_service_instances.where(:instance_number.gt => total_instances).destroy
    total_instances.times do |i|
      instance_number = i + 1
      self.grid_service_deploy.reload
      unless self.grid_service_deploy.running?
        raise "halting deploy of #{self.grid_service.to_path}, deploy was aborted: #{self.grid_service_deploy.reason}"
      end
      self.grid_service.reload
      unless self.grid_service.running? || self.grid_service.initialized?
        raise "halting deploy of #{self.grid_service.to_path}, desired state has changed"
      end
      self.deploy_service_instance(total_instances, deploy_futures, instance_number, deploy_rev)
      sleep 0.1
    end
    if deploy_futures.any?{|f| f.value.error?}
      raise DeployError.new("halting deploy of #{self.grid_service.to_path}, one or more instances failed")
    end

    self.grid_service_deploy.set(:_deploy_state => :success)
    log_service_event("service #{self.grid_service.to_path} deployed")
    info "service #{self.grid_service.to_path} has been deployed"

    true
  rescue DeployError => exc
    error exc.message
    log_service_event("deploy of #{self.grid_service.to_path} errored: #{exc.message}", EventLog::ERROR)
    self.grid_service_deploy.set(:_deploy_state => :error, :reason => exc.message)
    false
  rescue RpcClient::Error => exc
    error "Rpc error (#{self.grid_service.to_path}): #{exc.class.name} #{exc.message}"
    error exc.backtrace.join("\n") if exc.backtrace
    log_service_event("agent communication error while deploying #{self.grid_service.to_path}: #{exc.message}", EventLog::ERROR)
    self.grid_service_deploy.set(:_deploy_state => :error, :reason => exc.message)
    false
  rescue => exc
    error "Unknown error (#{self.grid_service.to_path}): #{exc.class.name} #{exc.message}"
    error exc.backtrace.join("\n") if exc.backtrace
    log_service_event("unknown error while deploying #{self.grid_service.to_path}: #{exc.message}", EventLog::ERROR)
    self.grid_service_deploy.set(:_deploy_state => :error, :reason => exc.message)
    false
  end

  # @param [Integer] total_instances
  # @param [Array<Celluloid::Future>] deploy_futures
  # @param [Integer] instance_number
  # @param [String] deploy_rev
  # @raise [DeployError]
  def deploy_service_instance(total_instances, deploy_futures, instance_number, deploy_rev)
    begin
      node = self.scheduler.select_node(
          self.grid_service, instance_number, self.nodes
      )
    rescue Scheduler::Error => exc
      raise DeployError, "Cannot find applicable node for service instance #{self.grid_service.to_path}-#{instance_number}: #{exc.message}"
    end

    grid_service_instance_deploy = @grid_service_deploy.grid_service_instance_deploys.create(
      instance_number: instance_number,
      host_node: node.node,
    )

    deploy_futures << Celluloid::Future.new {
      instance_deployer = GridServiceInstanceDeployer.new(grid_service_instance_deploy)
      instance_deployer.deploy(deploy_rev)
    }
    pending_deploys = deploy_futures.select{|f| !f.ready?}
    if pending_deploys.size >= (total_instances * self.min_health).floor || pending_deploys.size >= 20
      info "throttling service instance #{self.grid_service.to_path} deploy because of min_health limit (#{pending_deploys.size} instances in-progress)"
      pending_deploys[0].value rescue nil
      sleep 0.1 until pending_deploys.any?{|f| f.ready?}
    end
    if deploy_futures.any?{|f| f.ready? && f.value.error?}
      raise DeployError.new("halting deploy of #{self.grid_service.to_path}, one or more instances failed")
    end
  end

  # @return [Integer]
  def instance_count
    available_nodes = self.nodes.map { |n| n.clone } # we don't want to touch originals here
    max_instances = self.scheduler.instance_count(self.nodes.size, self.grid_service.container_count)
    nodes = []
    max_instances.times do |i|
      begin
        nodes << self.scheduler.select_node(
          self.grid_service, i + 1, available_nodes
        )
      rescue Scheduler::Error

      end
    end
    filtered_count = nodes.uniq.size
    self.scheduler.instance_count(filtered_count, self.grid_service.container_count)
  end

  # @return [Float]
  def min_health
    1.0 - (self.grid_service.deploy_opts.min_health || 0.8).to_f
  end

  # @param [String] reason
  # @param [String] msg
  def log_service_event(msg, severity = EventLog::INFO)
    EventLog.create(
      grid_id: self.grid_service.grid_id,
      grid_service_id: self.grid_service.id,
      msg: msg,
      severity: severity,
      type: 'service:deploy'.freeze
    )
  end
end
