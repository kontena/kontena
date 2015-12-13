require 'celluloid'
require_relative 'logging'
require_relative 'grid_service_scheduler'

class GridServiceDeployer
  include Logging
  include DistributedLocks

  class NodeMissingError < StandardError; end
  class DeployError < StandardError; end

  attr_reader :grid_service, :nodes, :scheduler

  ##
  # @param [#find_node] strategy
  # @param [GridService] grid_service
  # @param [Array<HostNode>] nodes
  def initialize(strategy, grid_service, nodes)
    @scheduler = GridServiceScheduler.new(strategy)
    @grid_service = grid_service
    @nodes = nodes
  end

  ##
  # Is deploy possible?
  #
  # @return [Boolean]
  def can_deploy?
    self.grid_service.container_count.times do |i|
      node = self.scheduler.select_node(
        self.grid_service, i + 1, self.nodes
      )
      return false unless node
    end

    true
  end

  # @return [Array<HostNode>]
  def selected_nodes
    nodes = []
    self.grid_service.container_count.times do |i|
      node = self.scheduler.select_node(
        self.grid_service, i + 1, self.nodes
      )
      nodes << node if node
    end

    nodes
  end

  # @param [Hash] creds
  # @return [Celluloid::Future]
  def deploy_async(creds = nil)
    Celluloid::Future.new{
      unless self.grid_service.reload.deploying?
        self.deploy(creds)
      end
    }
  end

  ##
  # @param [Hash] creds
  def deploy(creds = nil)
    info "starting to deploy #{self.grid_service.to_path}"
    self.grid_service.set_state('deploying')
    self.grid_service.set(:deployed_at => Time.now.utc)

    deploy_rev = Time.now.utc.to_s
    deploy_futures = []
    %w(TERM INT).each do |signal|
      Signal.trap(signal) { self.grid_service.set_state('running') }
    end
    total_instances = self.scheduler.instance_count(self.nodes.size, self.grid_service.container_count)
    total_instances.times do |i|
      instance_number = i + 1
      unless self.grid_service.deploying?
        raise "halting deploy of #{self.grid_service.to_path}, desired state has changed"
      end
      node = self.scheduler.select_node(
        self.grid_service, instance_number, self.nodes
      )
      unless node
        raise NodeMissingError.new("Cannot find applicable node for service instance #{self.grid_service.to_path}-#{instance_number}")
      end
      info "deploying service instance #{self.grid_service.to_path}-#{instance_number} to node #{node.name}"
      deploy_futures << Celluloid::Future.new {
        self.deploy_service_instance(node, instance_number, deploy_rev, creds)
      }
      pending_deploys = deploy_futures.select{|f| !f.ready?}
      if pending_deploys.size >= (total_instances * self.min_health).floor || pending_deploys.size >= 40
        info "throttling service instance #{self.grid_service.to_path} deploy because of min_health limit (#{pending_deploys.size} instances in-progress)"
        pending_deploys[0].value rescue nil
        sleep 0.1 until pending_deploys.any?{|f| f.ready?}
      end
      if deploy_futures.any?{|f| f.ready? && f.value == false}
        raise DeployError.new("halting deploy of #{self.grid_service.to_path}, one or more instances failed")
      end
      sleep 0.1
    end
    deploy_futures.select{|f| !f.ready?}.each{|f| f.value }

    self.cleanup_deploy(total_instances, deploy_rev)

    info "service #{self.grid_service.to_path} has been deployed"
    self.grid_service.set_state('running')

    true
  rescue NodeMissingError => exc
    self.grid_service.set_state('running')
    error exc.message
    info "service #{self.grid_service.to_path} deploy cancelled"
    false
  rescue DeployError => exc
    self.grid_service.set_state('running')
    error exc.message
    false
  rescue RpcClient::Error => exc
    self.grid_service.set_state('running')
    error "Rpc error (#{self.grid_service.to_path}): #{exc.class.name} #{exc.message}"
    error exc.backtrace.join("\n") if exc.backtrace
    false
  rescue => exc
    self.grid_service.set_state('running')
    error "Unknown error (#{self.grid_service.to_path}): #{exc.class.name} #{exc.message}"
    error exc.backtrace.join("\n") if exc.backtrace
    false
  end

  # @param [String] deploy_rev
  def cleanup_deploy(total_instances, deploy_rev)
    cleanup_futures = []
    self.grid_service.containers.where(:deploy_rev => {:$ne => deploy_rev}).each do |container|
      instance_number = container.name.match(/^.+-(\d+)$/)[1]
      container.set(:deleted_at => Time.now.utc)

      # just to be on a safe side.. we don't want to destroy anything accidentally
      if instance_number.to_i <= total_instances
        deployed_container = self.find_service_instance_container(instance_number, deploy_rev)
        if deployed_container.nil?
          next
        elsif deployed_container.host_node_id == container.host_node_id
          next
        end
      end

      cleanup_futures << Celluloid::Future.new {
        info "removing service instance #{container.to_path}"
        self.terminate_service_instance(instance_number, container.host_node)
      }
      pending_cleanups = cleanup_futures.select{|f| !f.ready?}
      if pending_cleanups.size > self.nodes.size
        pending_cleanups[0].value rescue nil
      end
    end
    self.grid_service.containers.unscoped.where(:container_id => nil, :deploy_rev => {:$ne => deploy_rev}).each do |container|
      container.destroy
    end
  end

  # @return [Integer]
  def instance_count
    self.scheduler.instance_count(self.nodes.size, self.grid_service.container_count)
  end

  # @param [HostNode] node
  # @param [Integer] instance_number
  # @param [String] deploy_rev
  # @param [Hash, NilClass] creds
  def deploy_service_instance(node, instance_number, deploy_rev, creds = nil)
    if !self.service_exists_on_node?(node, instance_number)
      self.terminate_service_instance(instance_number)
    end

    self.create_service_instance(node, instance_number, deploy_rev, creds)
    self.wait_for_service_to_start(node, instance_number, deploy_rev)
    true
  rescue => exc
    error "failed to deploy service instance #{self.grid_service.to_path}-#{instance_number} to node #{node.name}"
    error exc.message
    false
  end

  # @param [HostNode] node
  # @param [String] instance_number
  # @param [String] deploy_rev
  def wait_for_service_to_start(node, instance_number, deploy_rev)
    # node/agent has 60 seconds to do it's job
    Timeout.timeout(60) do
      sleep 0.5 until self.deployed_service_container_exists?(instance_number, deploy_rev)
      if self.wait_for_port?
        container = self.find_service_instance_container(instance_number, deploy_rev)
        sleep 0.5 until port_responding?(container, self.wait_for_port)
      end
    end
  end

  # @param [HostNode] node
  # @param [String] instance_number
  # @return [Boolean]
  def service_exists_on_node?(node, instance_number)
    container_name = "#{self.grid_service.name}-#{instance_number}"
    old_container = self.grid_service.containers.find_by(name: container_name)
    old_container && old_container.host_node && old_container.host_node == node
  end

  # @param [HostNode] node
  # @param [String] instance_number
  # @param [String] deploy_rev
  # @param [Hash, NilClass] creds
  def create_service_instance(node, instance_number, deploy_rev, creds)
    creator = Docker::ServiceCreator.new(self.grid_service, node)
    creator.create_service_instance(instance_number, deploy_rev, creds)
  end

  # @param [String] instance_number
  # @param [String] deploy_rev
  # @return [Boolean]
  def deployed_service_container_exists?(instance_number, deploy_rev)
    container = self.find_service_instance_container(instance_number, deploy_rev)
    if container && container.container_id
      true
    else
      false
    end
  end

  # @param [String] instance_number
  # @param [String] deploy_rev
  # @return [Container, NilClass]
  def find_service_instance_container(instance_number, deploy_rev)
    container_name = "#{self.grid_service.name}-#{instance_number}"
    self.grid_service.containers.find_by(name: container_name, deploy_rev: deploy_rev)
  end

  # @param [String] instance_number
  # @param [HostNode] node
  def terminate_service_instance(instance_number, node = nil)
    container_name = "#{self.grid_service.name}-#{instance_number}"
    if node.nil?
      container = self.grid_service.containers.find_by(name: container_name)
      return unless container
      return unless container.host_node
      node = container.host_node
    end
    return unless node
    terminator = Docker::ServiceTerminator.new(node)
    terminator.terminate_service_instance(container_name)
  end

  # @return [Float]
  def min_health
    1.0 - (self.grid_service.deploy_opts.min_health || 0.8).to_f
  end

  # @return [Boolean]
  def wait_for_port?
    !self.grid_service.deploy_opts.wait_for_port.nil?
  end

  # @return [Integer]
  def wait_for_port
    self.grid_service.deploy_opts.wait_for_port
  end

  ##
  # @param [Container] container
  # @param [String] port
  def port_responding?(container, port)
    rpc_client = RpcClient.new(container.host_node.node_id, 2)
    response = rpc_client.request('/agent/port_open?', container.network_settings[:ip_address], port)
    response['open']
  rescue RpcClient::Error
    return false
  end
end
