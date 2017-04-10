
describe GridServiceDeployer do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:grid_service_deploy) { GridServiceDeploy.create(grid_service: grid_service) }
  let(:node1) { HostNode.create!(node_id: SecureRandom.uuid, grid: grid) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(strategy, grid_service_deploy, grid.host_nodes.to_a) }

  describe '#selected_nodes' do
    before(:each) do
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
    end

    it 'returns instance_count amount of nodes by default' do
      expect(subject.selected_nodes.size).to eq(1)
    end

    it 'returns filtered amount of unique nodes if service has affinity' do
      service = GridService.create!(
        image_name: 'kontena/redis:2.8', name: 'redis', grid: grid,
        container_count: 3, affinity: ['label==foo']
      )
      service_deploy = GridServiceDeploy.create(grid_service: service)
      subject = described_class.new(strategy, service_deploy, grid.host_nodes.to_a)
      expect(subject.selected_nodes.size).to eq(3)
      expect(subject.selected_nodes.uniq.size).to eq(2)
    end
  end

  describe '#instance_count' do
    it 'returns grid_service#container_count by default' do
      expect(subject.instance_count).to eq(grid_service.container_count)
    end

    it 'returns count based on filtered nodes if strategy is daemon' do
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['bar'])
      service = GridService.create!(
        image_name: 'kontena/redis:2.8', name: 'redis', grid: grid,
        container_count: 3, affinity: ['label==foo']
      )
      service_deploy = GridServiceDeploy.create(grid_service: service)
      subject = described_class.new(
        Scheduler::Strategy::Daemon.new, service_deploy, grid.host_nodes.to_a
      )
      expect(subject.instance_count).to eq(6)
    end

    it 'returns count based on filtered nodes if strategy is daemon and stack is non-default' do
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['foo'])
      HostNode.create!(node_id: SecureRandom.uuid, grid: grid, labels: ['bar'])
      stack = grid.stacks.create(name: 'redis')
      service = GridService.create!(
        image_name: 'kontena/redis:2.8', name: 'redis', grid: grid, stack: stack,
        container_count: 1, affinity: ['label==foo'], strategy: 'daemon'
      )
      service_deploy = GridServiceDeploy.create(grid_service: service)
      subject = described_class.new(
        Scheduler::Strategy::Daemon.new, service_deploy, grid.host_nodes.to_a
      )
      expect(subject.instance_count).to eq(2)
    end
  end

  describe '#deploy_service_instance' do
    let(:deploy_rev) { Time.now.utc.to_s }

    let(:instance_deployer) { instance_double(GridServiceInstanceDeployer) }

    context "for a grid without host nodes" do
      it "fails with a scheduler error" do
        total_instances = 2
        deploy_futures = []
        instance_number = 1

        expect{
          subject.deploy_service_instance(total_instances, deploy_futures, instance_number, deploy_rev)
        }.to raise_error(GridServiceDeployer::DeployError, 'Cannot find applicable node for service instance test-grid/null/redis-1: There are no nodes available')
      end

    end

    context "for a grid with host nodes" do
      before(:each) do
        grid.host_nodes.create!(name: 'node1', node_id: SecureRandom.uuid)
        grid.host_nodes.create!(name: 'node2', node_id: SecureRandom.uuid)
      end

      it "aborts the service deploy if the instance deploy fails" do
        total_instances = 2
        deploy_futures = []
        instance_number = 1

        expect(GridServiceInstanceDeployer).to receive(:new).with(GridServiceInstanceDeploy) do |grid_service_instance_deploy|
          expect(grid_service_instance_deploy.grid_service_deploy).to eq grid_service_deploy
          expect(grid_service_instance_deploy.instance_number).to eq instance_number

          expect(instance_deployer).to receive(:deploy).with(deploy_rev) do
            grid_service_instance_deploy.set(:deploy_state => :error, :error => "testfail")
          end

          instance_deployer
        end

        expect{
          subject.deploy_service_instance(total_instances, deploy_futures, instance_number, deploy_rev)
        }.to raise_error(GridServiceDeployer::DeployError, 'halting deploy of test-grid/null/redis, one or more instances failed')
      end
    end
  end
end
