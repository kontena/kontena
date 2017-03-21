class GridServiceInstanceDeployer
  include Logging
  include WaitHelper

  attr_reader :grid_service

  def initialize(grid_service)
    @grid_service = grid_service
  end

  # @param [HostNode] node
  # @param [Integer] instance_number
  # @param [String] deploy_rev
  # @return [Boolean]
  def deploy(node, instance_number, deploy_rev)
    current_instance = current_service_instance(instance_number)
    if current_instance && current_instance.host_node != node
      # we need to stop instance if it's running on different node
      stop_current_instance(current_instance)
    end

    service_instance = create_service_instance(node, instance_number, deploy_rev)
    notify_node(node)
    wait_for_service_state(service_instance, 'running', deploy_rev)

    true
  rescue => exc
    error "failed to deploy service instance #{self.grid_service.to_path}-#{instance_number} to node #{node.name}"
    error exc.message
    error exc.backtrace.join("\n")
    false
  end

  # @param [GridServiceInstance] current_instance
  def stop_current_instance(current_instance)
    current_instance.set(desired_state: 'stopped')
    if current_instance.host_node.connected?
      notify_node(current_instance.host_node)
      wait_for_service_state(current_instance, 'stopped')
    end
  end

  # @param [GridServiceInstance] service_instance
  def wait_for_service_state(service_instance, state, rev = nil)
    wait_until!("service #{@grid_service.to_path} instance #{instance_number} is #{state} on node #{service_instance.host_node.to_path}", timeout: 300) do
      state_match = false
      if rev.nil?
        rev_match = true
      else
        rev_match = false
      end
      until state_match && rev_match do
        service_instance.reload
        state_match = service_instance.state == state
        rev_match = service_instance.rev == rev if rev
        sleep 1.0 unless state_match && rev_match
      end
    end

    true
  end

  # @param [HostNode] node
  # @param [String] instance_number
  # @param [String] deploy_rev
  # @return [GridServiceInstance]
  def create_service_instance(node, instance_number, deploy_rev)
    instance = current_service_instance(instance_number)
    unless instance
      instance = GridServiceInstance.create!(
        host_node: node, grid_service: self.grid_service, instance_number: instance_number
      )
    end
    instance.set(host_node_id: node.id, deploy_rev: deploy_rev, desired_state: 'running')

    instance
  end

  # @param [Integer] instance_number
  # @return [GridServiceInstance, NilClass]
  def current_service_instance(instance_number)
    GridServiceInstance.where(grid_service: self.grid_service, instance_number: instance_number).first
  end

  # @param [HostNode] node
  def notify_node(node)
    rpc_client = RpcClient.new(node.node_id, 2)
    rpc_client.request('/service_pods/notify_update', [])
  end
end
