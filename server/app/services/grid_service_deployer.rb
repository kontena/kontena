require_relative 'logging'
require_relative 'grid_service_scheduler'

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
    @nodes = nodes
  end

  # @return [Array<HostNode>]
  def selected_nodes
    nodes = []
    self.instance_count.times do |i|
      begin
        nodes << self.scheduler.select_node(
          self.grid_service, i + 1, self.nodes
        )
      rescue Scheduler::Error

      end
    end
    self.nodes.each{|n| n.schedule_counter = 0}

    nodes
  end

  def deploy
    info "starting to deploy #{self.grid_service.to_path}"
    self.grid_service_deploy.set(:deploy_state => :ongoing)
    deploy_rev = Time.now.utc.to_s
    self.grid_service.set(:deployed_at => deploy_rev)

    deploy_futures = []
    total_instances = self.instance_count
    self.grid_service.grid_service_instances.where(:instance_number.gt => total_instances).destroy
    total_instances.times do |i|
      instance_number = i + 1
      unless self.grid_service.reload.deploying?
        raise "halting deploy of #{self.grid_service.to_path}, desired state has changed"
      end
      self.deploy_service_instance(total_instances, deploy_futures, instance_number, deploy_rev)
      sleep 0.1
    end
    deploy_futures.select{|f| !f.ready?}.each{|f| f.value }

    self.grid_service_deploy.set(finished_at: Time.now.utc, :deploy_state => :success)
    info "service #{self.grid_service.to_path} has been deployed"

    true
  rescue DeployError => exc
    error exc.message
    self.grid_service_deploy.set(:deploy_state => :error, :reason => exc.message)
    false
  rescue RpcClient::Error => exc
    error "Rpc error (#{self.grid_service.to_path}): #{exc.class.name} #{exc.message}"
    error exc.backtrace.join("\n") if exc.backtrace
    self.grid_service_deploy.set(:deploy_state => :error, :reason => exc.message)
    false
  rescue => exc
    error "Unknown error (#{self.grid_service.to_path}): #{exc.class.name} #{exc.message}"
    error exc.backtrace.join("\n") if exc.backtrace
    self.grid_service_deploy.set(:deploy_state => :error, :reason => exc.message)
    false
  ensure
    self.grid_service_deploy.set(:finished_at => Time.now.utc)
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

    info "deploying service instance #{self.grid_service.to_path}-#{instance_number} to node #{node.name}"
    deploy_futures << Celluloid::Future.new {
      instance_deployer = GridServiceInstanceDeployer.new(self.grid_service)
      instance_deployer.deploy(node, instance_number, deploy_rev)
    }
    pending_deploys = deploy_futures.select{|f| !f.ready?}
    if pending_deploys.size >= (total_instances * self.min_health).floor || pending_deploys.size >= 20
      info "throttling service instance #{self.grid_service.to_path} deploy because of min_health limit (#{pending_deploys.size} instances in-progress)"
      pending_deploys[0].value rescue nil
      sleep 0.1 until pending_deploys.any?{|f| f.ready?}
    end
    if deploy_futures.any?{|f| f.ready? && f.value == false}
      raise DeployError.new("halting deploy of #{self.grid_service.to_path}, one or more instances failed")
    end
  end

  # @return [Integer]
  def instance_count
    max_instances = self.scheduler.instance_count(self.nodes.size, self.grid_service.container_count)
    nodes = []
    max_instances.times do |i|
      begin
        nodes << self.scheduler.select_node(
          self.grid_service, i + 1, self.nodes
        )
      rescue Scheduler::Error

      end
    end
    self.nodes.each{|n| n.schedule_counter = 0}
    filtered_count = nodes.uniq.size
    self.scheduler.instance_count(filtered_count, self.grid_service.container_count)
  end

  # @return [Float]
  def min_health
    1.0 - (self.grid_service.deploy_opts.min_health || 0.8).to_f
  end
end
