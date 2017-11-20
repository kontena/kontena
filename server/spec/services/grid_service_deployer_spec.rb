
describe GridServiceDeployer do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:grid_service_deploy) { GridServiceDeploy.create(grid_service: grid_service, started_at: Time.now.utc) }
  let(:node1) { grid.create_node!('node-1', node_id: SecureRandom.uuid, node_number: 1, mem_total: 1.gigabytes) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(strategy, grid_service_deploy, grid.host_nodes.to_a) }
  let(:deploy_rev) { Time.now.utc.to_s }

  describe '#selected_nodes' do
    before(:each) do
      grid.create_node!('node-1', node_id: SecureRandom.uuid, labels: ['foo'], mem_total: 1.gigabytes)
      grid.create_node!('node-2', node_id: SecureRandom.uuid, labels: ['foo'], mem_total: 1.gigabytes)
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

    context 'with labled nodes' do
      before do
        grid.create_node!('node-1', node_id: SecureRandom.uuid, labels: ['foo'], mem_total: 1.gigabytes)
        grid.create_node!('node-2', node_id: SecureRandom.uuid, labels: ['foo'], mem_total: 1.gigabytes)
        grid.create_node!('node-3', node_id: SecureRandom.uuid, labels: ['bar'], mem_total: 1.gigabytes)
      end

      it 'returns count based on filtered nodes if strategy is daemon' do
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
  end

  context "for a grid without host nodes" do
    describe '#deploy_service_instance' do
      it "fails with a scheduler error" do
        total_instances = 2
        deploy_futures = []
        instance_number = 1

        expect{
          subject.deploy_service_instance(total_instances, deploy_futures, instance_number, deploy_rev)
        }.to raise_error(GridServiceDeployer::DeployError, 'Cannot find applicable node for service instance test-grid/null/redis-1: There are no nodes available')
      end
    end
  end

  context "for a grid with host nodes" do
    before(:each) do
      grid.create_node!('node1', node_id: SecureRandom.uuid, mem_total: 1.gigabytes)
      grid.create_node!('node2', node_id: SecureRandom.uuid, mem_total: 1.gigabytes)
    end

    describe '#deploy_service_instance' do
      let(:instance_deployer) { instance_double(GridServiceInstanceDeployer) }

      it "aborts the service deploy if the instance deploy fails", :celluloid => true do
        total_instances = 2
        deploy_futures = []
        instance_number = 1

        expect(GridServiceInstanceDeployer).to receive(:new).with(GridServiceInstanceDeploy) do |grid_service_instance_deploy|
          expect(grid_service_instance_deploy.grid_service_deploy).to eq grid_service_deploy
          expect(grid_service_instance_deploy.instance_number).to eq instance_number

          expect(instance_deployer).to receive(:deploy).with(deploy_rev) do
            grid_service_instance_deploy.set(:_deploy_state => :error, :error => "testfail")
          end

          instance_deployer
        end

        expect{
          subject.deploy_service_instance(total_instances, deploy_futures, instance_number, deploy_rev)
        }.to raise_error(GridServiceDeployer::DeployError, 'halting deploy of test-grid/null/redis, one or more instances failed')
      end
    end

    describe '#deploy' do

      context "for multiple concurrent instance deploys" do
        let(:grid_service) {
          grid.grid_services.create!(
            name: 'redis',
            image_name: 'kontena/redis:2.8',
            deploy_opts: {
              min_health: 0.0,
            },
            container_count: 2,
          )
        }
        let(:grid_service_deploy) { GridServiceDeploy.create(grid_service: grid_service, started_at: Time.now.utc) }
        let(:subject) { described_class.new(strategy, grid_service_deploy, grid.host_nodes.to_a) }

        before do
          grid_service_deploy.started_at = Time.now.utc
        end

        it "fails the service deploy if one of the concurrent instance deploys fail", :celluloid => true do
          expect(subject).to receive(:deploy_service_instance).once.with(2, Array, 1, String) do |total_instances, deploy_futures, instance_number, deploy_rev|
            deploy_futures << Celluloid::Future.new {
              sleep 0.01

              grid_service_deploy.grid_service_instance_deploys.create(
                instance_number: instance_number,
                host_node: grid.host_nodes.first,
                deploy_state: :success,
              )
            }
          end
          expect(subject).to receive(:deploy_service_instance).once.with(2, Array, 2, String) do |total_instances, deploy_futures, instance_number, deploy_rev|
            deploy_futures << Celluloid::Future.new {
              sleep 0.01

              grid_service_deploy.grid_service_instance_deploys.create(
                instance_number: instance_number,
                host_node: grid.host_nodes.first,
                deploy_state: :error,
                error: "testfail 2"
              )
            }
          end

          allow(grid_service).to receive(:deploying?).and_return(true) # XXX: why is it not deploying?

          expect{
            subject.deploy
          }.to change{grid_service_deploy.grid_service_instance_deploys.count}.from(0).to(2)

          grid_service_deploy.reload

          expect(grid_service_deploy).to be_error
        end

        it "fails the service deploy if aborted", :celluloid => true do
          expect(subject).to receive(:deploy_service_instance).once.with(2, Array, 1, String) do |total_instances, deploy_futures, instance_number, deploy_rev|
            grid_service_deploy.abort! "testing"

            deploy_futures << Celluloid::Future.new {
              grid_service_deploy.grid_service_instance_deploys.create(
                instance_number: instance_number,
                host_node: grid.host_nodes.first,
                deploy_state: :success,
              )
            }
          end

          expect(subject).to_not receive(:deploy_service_instance)

          subject.deploy
          # TODO: expect first instance to get deployed, once the deployer waits for pending instance deploys to finish on errors
          # expect{ ... }.to change{grid_service_deploy.grid_service_instance_deploys.count}.from(0).to(1)

          grid_service_deploy.reload

          expect(grid_service_deploy).to be_error
          expect(grid_service_deploy.reason).to eq "halting deploy of test-grid/null/redis, deploy was aborted: testing"
        end
      end
    end
  end

end
