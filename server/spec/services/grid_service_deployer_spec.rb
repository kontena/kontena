
describe GridServiceDeployer do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:grid_service_deploy) { GridServiceDeploy.create(grid_service: grid_service) }
  let(:node1) { HostNode.create!(node_id: SecureRandom.uuid, grid: grid) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(strategy, grid_service_deploy, grid.host_nodes.to_a) }
  let(:deploy_rev) { Time.now.utc.to_s }

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
      grid.host_nodes.create!(name: 'node1', node_id: SecureRandom.uuid)
      grid.host_nodes.create!(name: 'node2', node_id: SecureRandom.uuid)
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
            grid_service_instance_deploy.set(:deploy_state => :error, :error => "testfail")
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
        let(:grid_service_deploy) { GridServiceDeploy.create(grid_service: grid_service) }
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
      end
    end
  end

end
