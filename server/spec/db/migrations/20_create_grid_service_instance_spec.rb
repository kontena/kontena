require_relative '../../../db/migrations/20_create_grid_service_instance'

describe CreateGridServiceInstance do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:node) do
    HostNode.create!(
      node_id: SecureRandom.uuid, grid: grid, name: 'node-1', node_number: 1,
      connected: true
    )
  end
  let(:service) do
    GridService.create!(
      image_name: 'kontena/redis:2.8', name: 'redis',
      grid: grid, container_count: 1, stateful: true, state: 'running'
    )
  end

  it 'creates a service instance from a volume container' do
    node.containers.create!(
      grid_service: service,
      grid: grid,
      container_type: 'volume',
      instance_number: 1,
      state: { 'running' => false }
    )
    described_class.up
    instance = service.grid_service_instances.first
    expect(instance.host_node).to eq(node)
    expect(instance.instance_number).to eq(1)
    expect(instance.desired_state).to eq('running')
    expect(instance.state).to eq('stopped')
  end

  it 'creates a service instance from a container' do
    node.containers.create!(
      grid_service: service,
      grid: grid,
      container_type: 'container',
      instance_number: 1,
      state: { 'running' => true }
    )
    described_class.up
    instance = service.grid_service_instances.first
    expect(instance.host_node).to eq(node)
    expect(instance.instance_number).to eq(1)
    expect(instance.desired_state).to eq('running')
    expect(instance.state).to eq('running')
  end
end
