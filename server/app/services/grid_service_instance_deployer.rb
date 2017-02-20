class GridServiceInstanceDeployer
  include Logging

  attr_reader :grid_service

  def initialize(grid_service)
    @grid_service = grid_service
  end

  # @param [HostNode] node
  # @param [Integer] instance_number
  # @param [String] deploy_rev
  # @return [Boolean]
  def deploy(node, instance_number, deploy_rev)
    service_instance = create_service_instance(node, instance_number, deploy_rev)
    notify_node(node)
    wait_for_service_to_start(service_instance)
    true
  rescue => exc
    error "failed to deploy service instance #{self.grid_service.to_path}-#{instance_number} to node #{node.name}"
    error exc.message
    error exc.backtrace.join("\n")
    false
  end

  # @param [GridServiceInstance] service_instance
  def wait_for_service_to_start(service_instance)
    Timeout.timeout(300) do
      until service_instance.reload.state == 'running' do
        sleep 1.0
      end
    end
  end

  # @param [HostNode] node
  # @param [String] instance_number
  # @param [String] deploy_rev
  # @return [GridServiceInstance]
  def create_service_instance(node, instance_number, deploy_rev)
    i = GridServiceInstance.where(grid_service: self.grid_service, instance_number: instance_number).first
    unless i
      i = GridServiceInstance.create!(
        host_node: node, grid_service: self.grid_service, instance_number: instance_number
      )
    end
    set = { host_node_id: node.id, deploy_rev: deploy_rev, desired_state: 'running' }
    set[:state] = 'initialized' if i.host_node != node
    i.set(set)

    i
  rescue => exc
    puts exc.message
  end

  def notify_node(node)
    rpc_client = RpcClient.new(node.node_id, 2)
    rpc_client.request('/service_pods/notify_update', [])
  end
end
