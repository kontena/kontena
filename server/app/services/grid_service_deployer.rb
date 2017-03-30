require_relative 'logging'
require_relative 'grid_service_scheduler'

class GridServiceDeployer
  include Logging

  class DeployError < StandardError; end

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

  # @return [Boolean]
  def deploy
    deploy_rev = Time.now.utc.to_s
    info "starting to deploy #{self.grid_service.to_path} at #{deploy_rev}"
    self.grid_service_deploy.set(:deploy_state => :ongoing)
    self.grid_service.set(:deployed_at => deploy_rev)

    total_instances = self.instance_count
    self.grid_service.grid_service_instances.where(:instance_number.gt => total_instances).destroy

    deploy_futures = []
    total_instances.times do |i|
      instance_number = i + 1
      unless self.grid_service.reload.deploying?
        raise DeployError, "desired state has changed"
      end

      deploy_futures << self.deploy_service_instance(instance_number, deploy_rev)

      pending_deploys = deploy_futures.select{|f| !f.ready?}
      if pending_deploys.size >= (total_instances * self.min_health).floor || pending_deploys.size >= 20
        info "throttling service instance #{self.grid_service.to_path} deploy because of min_health limit (#{pending_deploys.size} instances in-progress)"
        sleep 0.1 until pending_deploys.any?{|f| f.ready? }
      end

      # bail out early if anything fails
      if deploy_futures.select{|f| f.ready? }.map{|f| f.value }.any?{|d| d.error? } # raises on any Future exceptions
        raise DeployError, "one or more instances failed"
      end

      sleep 0.1
    end

    # wait on all Futures
    if deploy_futures.map{|f| f.value }.any?{|d| d.error? } # raises on any Future exceptions
      raise DeployError, "one or more instances failed"
    end

    info "service #{self.grid_service.to_path} has been deployed"
    self.grid_service_deploy.success!

    true
  rescue => exc
    error "Failed to deploy (#{self.grid_service.to_path}): #{exc.class.name}: #{exc.message}"
    error exc.backtrace.join("\n") if exc.backtrace

    self.grid_service_deploy.set(:deploy_state => :error, :reason => "#{exc.class}: #{exc}")

    # Wait for any remaining instance deploy futures
    deploy_futures.map{|f| f.value rescue nil }

    false
  ensure
    self.grid_service_deploy.set(:finished_at => Time.now.utc)
  end

  # @param [Integer] instance_number
  # @param [String] deploy_rev
  # @raise [DeployError] scheduling failed
  # @return [Celluloid::Future] running deploy
  def deploy_service_instance(instance_number, deploy_rev)
    begin
      node = self.scheduler.select_node(
          self.grid_service, instance_number, self.nodes
      )
    rescue Scheduler::Error => exc
      raise DeployError, "Cannot find applicable node for service instance #{self.grid_service.to_path}-#{instance_number}: #{exc.message}"
    end

    grid_service_instance_deploy = @grid_service_deploy.grid_service_instance_deploys.create(
      instance_number: instance_number,
      host_node: node,
    )

    info "deploying service instance #{self.grid_service.to_path}-#{instance_number} to node #{node.name}"
    Celluloid::Future.new {
      instance_deployer = GridServiceInstanceDeployer.new(grid_service_instance_deploy)
      instance_deployer.deploy(deploy_rev)
    }
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
