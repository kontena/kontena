class VolumeInstanceDeployer

  # @param node [HostNode]
  # @param service_volume [ServiceVolume]
  # @param instance_number [Fixnum]
  # @raise [RpcClient::Error]
  def deploy(node, service_volume, instance_number)
    volume_name = service_volume.volume.name_for_service(service_volume.grid_service, instance_number)
    volume_instance = node.volume_instances.find_by(name: volume_name)
    unless volume_instance
      volume_instance = VolumeInstance.create!(host_node: node, volume: service_volume.volume, name: volume_name)
      rpc_client = RpcClient.new(node.node_id, 2)
      rpc_client.request('/volumes/notify_update', [])
    end
    volume_instance
  end
end
