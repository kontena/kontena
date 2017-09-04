describe VolumeInstanceDeployer do
  let(:grid) do
    Grid.create!(name: 'foo')
  end

  let(:volume) do
    grid.volumes.create!(name: 'foo', scope: 'instance', driver: 'local')
  end

  let(:service) do
    grid.grid_services.create!(name: 'redis', image_name: 'redis')
  end

  let(:node) { HostNode.create!(node_id: SecureRandom.uuid, name: 'node', node_number: 1) }

  it 'creates volume instance if needed' do
    expect_any_instance_of(RpcClient).to receive(:request).with('/volumes/notify_update', [])
    service.service_volumes << ServiceVolume.new(volume: volume)
    expect {
      subject.deploy(node, service.service_volumes[0], 1)
    }.to change{ VolumeInstance.count }.by(1)
  end

  it 'creates volume instance if needed' do
    expect_any_instance_of(RpcClient).not_to receive(:request).with('/volumes/notify_update', [])
    node.volume_instances.create!(volume: volume, name: volume.name_for_service(service, 1))
    service.service_volumes << ServiceVolume.new(volume: volume)
    expect {
      subject.deploy(node, service.service_volumes[0], 1)
    }.not_to change{ VolumeInstance.count }
  end
end
