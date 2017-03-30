class GridServiceInstanceDeployer
  include Logging
  include WaitHelper

  attr_reader :grid_service

  class Error < StandardError; end

  class AgentError < Error; end
  class StateError < Error; end

  # @param grid_service_instance_deploy [GridServiceInstanceDeploy]
  def initialize(grid_service_instance_deploy)
    @grid_service_instance_deploy = grid_service_instance_deploy
    @grid_service = grid_service_instance_deploy.grid_service_deploy.grid_service
    @instance_number = grid_service_instance_deploy.instance_number
    @host_node = grid_service_instance_deploy.host_node
  end

  # @param deploy_rev [String]
  # @return [GridServiceInstanceDeploy] in error or success state
  def deploy(deploy_rev)
    info "Deploying service instance #{@grid_service.to_path}-#{@instance_number} to node #{@host_node.name} at #{deploy_rev}"

    @grid_service_instance_deploy.set(:deploy_state => :ongoing)

    service_instance = get_service_instance

    if service_instance.nil?
      service_instance = create_service_instance
    elsif service_instance.host_node != @host_node
      # we need to stop instance if it's running on different node
      stop_current_instance(service_instance, deploy_rev)
    end

    ensure_service_instance(service_instance, @host_node, deploy_rev, 'running')

  rescue => error
    warn "Failed to deploy service instance #{@grid_service.to_path}-#{@instance_number} to node #{@host_node.name}: #{error.class}: #{error}\n#{error.backtrace.join("\n")}"
    @grid_service_instance_deploy.set(:deploy_state => :error, :error => "#{error.class}: #{error}")
  else
    @grid_service_instance_deploy.set(:deploy_state => :success)
  end

  # @param service_instance [GridServiceInstance]
  # @param deploy_rev [String]
  def stop_current_instance(service_instance, deploy_rev)
    ensure_service_instance(service_instance, service_instance.host_node, deploy_rev, 'stopped')

  rescue => error
    warn "Failed to stop existing service #{@grid_service.to_path} instance #{service_instance.instance_number} on old node #{service_instance.host_node}: #{error}"
  end

  # Update service instance, notify node, wait for update, and ensure that service is in desired state.
  # Returns updated GridServiceInstance, or raises on any errors.
  #
  # @param service_instance [GridServiceInstance]
  # @param node [String] move to host node
  # @param deploy_rev [String] revision
  # @param desired_state [String] set and check for container state
  # @raise [RpcClient::TimeoutError] notify node failed
  # @raise [AgentError] agent failed to apply update
  # @raise [StateError] unexpected state after update
  # @raise [Timeout::Error] no update from agent
  # @return [GridServiceInstance]
  def ensure_service_instance(service_instance, node, deploy_rev, desired_state)
    raise "Host node is missing" unless node
    raise "Host node is disconnected" unless node.connected?

    service_instance.set(
      host_node_id: node.id,
      deploy_rev: deploy_rev,
      desired_state: desired_state,
      rev: nil, # reset
    )

    notify_node(node)

    service_instance = wait_until!("service #{@grid_service.to_path} instance #{service_instance.instance_number} is #{desired_state} on node #{node.to_path} at #{deploy_rev}", timeout: 300) do
      service_instance.reload

      next nil unless service_instance.rev && service_instance.rev >= deploy_rev

      service_instance
    end

    if service_instance.error
      raise AgentError, service_instance.error
    elsif service_instance.rev > deploy_rev
      raise StateError, "Service instance was re-deployed" # by someone else
    elsif service_instance.state != desired_state
      raise StateError, "Service instance is not #{desired_state}, but #{service_instance.state}"
    else
      return service_instance
    end
  end

  # @return [GridServiceInstance]
  def create_service_instance
    GridServiceInstance.create!(grid_service: @grid_service, instance_number: @instance_number)
  end

  # @return [GridServiceInstance, NilClass]
  def get_service_instance
    GridServiceInstance.where(grid_service: @grid_service, instance_number: @instance_number).first
  end

  # @param [HostNode] node
  # @raise [RpcClient::TimeoutError]
  def notify_node(node, timeout: 2.0)
    rpc_client = RpcClient.new(node.node_id, timeout)
    rpc_client.request('/service_pods/notify_update', [])
  end
end
