class GridServiceInstanceDeployer
  include Logging

  attr_reader :grid_service

  def initialize(grid_service)
    @grid_service = grid_service
  end

  # @param [HostNode] node
  # @param [Integer] instance_number
  # @param [String] deploy_rev
  # @param [Hash, NilClass] creds
  # @return [Boolean]
  def deploy(node, instance_number, deploy_rev, creds = nil)
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
    # node/agent has 5 minutes to do it's job
    Timeout.timeout(300) do
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

  # @return [Boolean]
  def wait_for_port?
    !self.wait_for_port.nil?
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
    if container.overlay_cidr
      ip = container.overlay_cidr.ip
    else
      ip = '127.0.0.1'
    end
    response = rpc_client.request('/agent/port_open?', ip, port)
    response['open']
  rescue RpcClient::Error
    return false
  end
end
