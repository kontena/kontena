
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

  describe '#stop_current_instance' do
    it 'sets desired_state to stopped' do
      instance = grid_service.grid_service_instances.create!(
        instance_number: 2, deploy_rev: (Time.now.utc - 1.day).to_s, host_node: node
      )
      subject.stop_current_instance(instance)
      expect(instance.reload.desired_state).to eq('stopped')
    end

    it 'sets desired_state to stopped even host_node is missing' do
      instance = grid_service.grid_service_instances.create!(
        instance_number: 2, deploy_rev: (Time.now.utc - 1.day).to_s
      )
      subject.stop_current_instance(instance)
      expect(instance.reload.desired_state).to eq('stopped')
    end

    it 'notifies node and waits instance to stop if node connected' do
      instance = grid_service.grid_service_instances.create!(
        instance_number: 2, deploy_rev: (Time.now.utc - 1.day).to_s, host_node: node
      )
      allow(node).to receive(:connected?).and_return(true)
      expect(subject).to receive(:notify_node).with(node)
      expect(subject).to receive(:wait_for_service_state)
      subject.stop_current_instance(instance)
      expect(instance.reload.desired_state).to eq('stopped')
    end
  end

  describe '#wait_for_service_state' do
    it 'returns true if service state matches' do
      rev = Time.now.utc.to_s
      instance = grid_service.grid_service_instances.create!(
        desired_state: 'running',
        state: 'running',
        deploy_rev: rev,
        instance_number: 2, host_node: node
      )
      expect(subject.wait_for_service_state(instance, 'running')).to be_truthy
    end

    it 'returns true if service state and rev matches' do
      rev = Time.now.utc.to_s
      instance = grid_service.grid_service_instances.create!(
        desired_state: 'running',
        state: 'running',
        deploy_rev: rev, rev: rev,
        instance_number: 2, host_node: node
      )
      expect(subject.wait_for_service_state(instance, 'running', rev)).to be_truthy
    end
  end

  describe '#ensure_volume_instance' do
    let(:volume) do
      grid.volumes.create!(name: 'foo', scope: 'instance', driver: 'local')
    end

    it 'schedules volume instances' do
      grid_service.service_volumes << ServiceVolume.new(volume: volume, path: '/data')
      grid_service.service_volumes << ServiceVolume.new(bind_mount: '/tmp', path: '/data')
      volume_scheduler = double
      expect(VolumeInstanceDeployer).to receive(:new).and_return(volume_scheduler)
      expect(volume_scheduler).to receive(:deploy).with(node, grid_service.service_volumes[0], 2)
      subject.ensure_volume_instance(node, 2)
    end
  end
end
