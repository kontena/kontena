require 'celluloid'
require_relative 'grid_scheduler'
require_relative 'load_balancer_configurer'

class GridServiceDeployer
  include Celluloid
  include Celluloid::Logger

  attr_reader :grid_service, :nodes, :scheduler, :config

  ##
  # @param [#find_node] strategy
  # @param [GridService] grid_service
  # @param [Array<HostNode>] nodes
  def initialize(strategy, grid_service, nodes, config = {})
    @scheduler = GridScheduler.new(strategy)
    @grid_service = grid_service
    @nodes = nodes
    @config = config
  end


  ##
  # Is deploy possible?
  #
  # @return [Boolean]
  def can_deploy?
    self.grid_service.container_count.times do |i|
      container_name = "#{self.grid_service.name}-#{i + 1}"
      node = self.scheduler.select_node(self.grid_service, container_name, self.nodes)
      return false unless node
    end

    true
  end

  ##
  # @param [Hash] creds
  def deploy(creds = nil)
    prev_state = self.grid_service.state
    self.grid_service.set_state('deploying')

    self.configure_load_balancer
    pulled_nodes = Set.new
    deploy_rev = Time.now.utc.to_s
    self.grid_service.container_count.times do |i|
      container_name = "#{self.grid_service.name}-#{i + 1}"
      node = self.scheduler.select_node(self.grid_service, container_name, self.nodes)

      raise "Cannot find applicable node for container: #{container_name}" unless node

      unless pulled_nodes.include?(node)
        self.ensure_image(node, self.grid_service.image_name, creds)
        pulled_nodes << node
      end
      self.deploy_service_container(node, container_name, deploy_rev)
    end

    self.grid_service.containers.where(:deploy_rev => {:$ne => deploy_rev}).each do |container|
      self.remove_service_container(container)
    end
    self.grid_service.set_state('running')

    true
  rescue RpcClient::Error => exc
    self.grid_service.set_state(prev_state)
    error "RPC error: #{exc.class.name} #{exc.message}"
    false
  rescue => exc
    self.grid_service.set_state(prev_state)
    error "Unknown error: #{exc.class.name} #{exc.message}"
    error exc.backtrace.join("\n") if exc.backtrace
    false
  end

  ##
  # @param [HostNode] node
  # @param [String] image_name
  # @param [Hash] creds
  def ensure_image(node, image_name, creds = nil)
    image = image_puller(node, creds).pull_image(image_name)
    self.grid_service.update_attribute(:image_id, image.id)
  end

  ##
  # @param [HostNode] node
  # @param [Hash] creds
  def image_puller(node, creds = nil)
    Docker::ImagePuller.new(node, creds)
  end

  ##
  # @param [HostNode] node
  # @param [String] container_name
  # @param [String] deploy_rev
  def deploy_service_container(node, container_name, deploy_rev)
    old_container = self.grid_service.container_by_name(container_name)
    if old_container && old_container.up_to_date? && old_container.status == 'running'
      old_container.update_attribute(:deploy_rev, deploy_rev)
      return
    end
    if old_container && old_container.exists_on_node?
      self.remove_service_container(old_container)
    end
    container = self.create_service_container(node, container_name, deploy_rev)
    self.start_service_container(container)
    Timeout.timeout(20) do
      sleep 0.5 until container_running?(container)
      if self.config[:wait_for_port]
        sleep 0.5 until port_responding?(container, self.config[:wait_for_port])
      end
    end
  end

  ##
  # @param [HostNode] node
  # @param [String] container_name
  # @return [Container]
  def create_service_container(node, container_name, deploy_rev)
    creator = Docker::ContainerCreator.new(self.grid_service, node)
    creator.create_container(container_name, deploy_rev)
  end

  ##
  # @param [Container] container
  def start_service_container(container)
    starter = Docker::ContainerStarter.new(container)
    starter.start_container
  end

  ##
  # @param [Container] container
  def remove_service_container(container)
    Docker::ContainerRemover.new(container).remove_container
  end

  ##
  # @param [Container] container
  # @return [Boolean]
  def container_running?(container)
    container.reload.running?
  end

  ##
  # @param [Container] container
  # @param [String] port
  def port_responding?(container, port)
    node = container.host_node
    return false unless node

    rpc_client = node.rpc_client(2)
    response = rpc_client.request('/agent/port_open?', container.network_settings[:ip_address], port)
    response['open']
  rescue RpcClient::Error
    return false
  end

  def configure_load_balancer
    load_balancers = self.grid_service.linked_to_load_balancers
    return if load_balancers.size == 0

    load_balancer = load_balancers[0]
    node = self.grid_service.grid.host_nodes.connected.first
    return unless node

    lb_conf = LoadBalancerConfigurer.new(
      node.rpc_client, load_balancer, self.grid_service
    )
    lb_conf.async.configure
  end
end
