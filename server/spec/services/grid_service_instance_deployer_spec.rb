
describe GridServiceInstanceDeployer do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:node) { HostNode.create!(node_id: SecureRandom.uuid) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(grid_service) }

  describe '#create_service_instance' do
    it 'creates a new instance if not exist' do
      grid_service
      instance_number = 2
      deploy_rev = Time.now.utc.to_s
      expect {
        subject.create_service_instance(node, instance_number, deploy_rev)
      }.to change { grid_service.grid_service_instances.count }.by(1)
      instance = grid_service.grid_service_instances.first
      expect(instance.instance_number).to eq(instance_number)
      expect(instance.deploy_rev).to eq(deploy_rev)
      expect(instance.host_node).to eq(node)
    end

    it 'updates existing instance if exist' do
      instance_number = 2
      grid_service.grid_service_instances.create!(
        instance_number: instance_number, deploy_rev: Time.now.utc.to_s, host_node: node
      )
      deploy_rev = Time.now.utc.to_s
      expect {
        subject.create_service_instance(node, instance_number, deploy_rev)
      }.to change { grid_service.grid_service_instances.count }.by(0)
      instance = grid_service.grid_service_instances.first
      expect(instance.instance_number).to eq(instance_number)
      expect(instance.deploy_rev).to eq(deploy_rev)
      expect(instance.host_node).to eq(node)
    end
  end
end
