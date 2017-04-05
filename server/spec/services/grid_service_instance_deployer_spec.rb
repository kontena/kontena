
describe GridServiceInstanceDeployer do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:node) { HostNode.create!(name: "node", node_id: SecureRandom.uuid,
    connected: true,
  ) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:service_deploy) { GridServiceDeploy.create(grid_service: grid_service) }

  let(:instance_number) { 2 }
  let(:instance_deploy) { service_deploy.grid_service_instance_deploys.create(
    instance_number: instance_number,
    host_node: node,
  ) }
  let(:subject) { described_class.new(instance_deploy) }

  let(:deploy_rev) { Time.now.utc.to_s }

  describe '#deploy' do
    it "updates the instance deploy state to ongoing and then success" do
      expect(subject).to receive(:ensure_volume_instance)
      expect(subject).to receive(:ensure_service_instance).with(deploy_rev) do
        expect(instance_deploy).to be_ongoing
      end

      expect{subject.deploy(deploy_rev)}.to change{instance_deploy.reload.deploy_state}.from(:created).to(:success)
    end

    it "updates the instance deploy state to error on failure" do
      expect(subject).to receive(:ensure_volume_instance)
      expect(subject).to receive(:ensure_service_instance).with(deploy_rev).and_raise(GridServiceInstanceDeployer::ServiceError, "Docker::Error::NotFoundError: No such image: redis:nonexist")

      expect{subject.deploy(deploy_rev)}.to change{instance_deploy.reload.deploy_state}.from(:created).to(:error)
      expect(instance_deploy.reload.error).to eq "GridServiceInstanceDeployer::ServiceError: Docker::Error::NotFoundError: No such image: redis:nonexist"
    end
  end

  context "Without any existing deployed instance" do
    describe '#get_service_instance' do
      it "returns nil" do
        expect(subject.get_service_instance).to be_nil
      end
    end

    describe '#ensure_service_instance' do
      it "deploys a new instance" do
        expect(subject).not_to receive(:stop_current_instance)

        expect(subject).to receive(:deploy_service_instance).once.with(GridServiceInstance, node, deploy_rev, 'running').and_call_original
        expect(subject).to receive(:notify_node).with(node)
        expect(subject).to receive(:wait_until!).with("service test-grid/null/redis-2 is running on node /node at #{deploy_rev}", timeout: 300) do
          grid_service.grid_service_instances.first.set(rev: deploy_rev, state: 'running')
        end

        expect{
          subject.ensure_service_instance(deploy_rev)
        }.to change{grid_service.grid_service_instances.count}.from(0).to(1)

        service_instance = grid_service.grid_service_instances.first

        expect(service_instance.instance_number).to eq instance_number
        expect(service_instance.host_node).to eq node
        expect(service_instance.deploy_rev).to eq deploy_rev
        expect(service_instance.desired_state).to eq 'running'
      end
    end
  end

  context "With an existing deployed instance on the same host node" do
    let(:old_rev) { 1.hours.ago.utc.to_s }

    let(:service_instance) {
      grid_service.grid_service_instances.create!(
        instance_number: instance_number,
        deploy_rev: old_rev,
        host_node: node,
      )
    }

    before do
      service_instance
    end

    describe '#get_service_instance' do
      it "returns the matching instance" do
        expect(subject.get_service_instance).to_not be_nil do |instance|
          expect(instance.grid_service_id).to eq grid_service.id
          expect(instance.instance_number).to eq instance_number
          expect(instance.deploy_rev).to eq earlier
        end
      end
    end

    describe '#create_service_instance' do
      it "fails with a duplicate instance" do
        expect{subject.create_service_instance}.to raise_error Mongoid::Errors::Validations, /Instance number is already taken/
      end
    end

    describe '#ensure_service_instance' do
      it "re-deploys the instance" do
        expect(subject).not_to receive(:stop_current_instance)

        expect(subject).to receive(:deploy_service_instance).once.with(GridServiceInstance, node, deploy_rev, 'running').and_call_original
        expect(subject).to receive(:notify_node).with(node)
        expect(subject).to receive(:wait_until!).with("service test-grid/null/redis-2 is running on node /node at #{deploy_rev}", timeout: 300) do
          grid_service.grid_service_instances.first.set(rev: deploy_rev, state: 'running')
        end

        expect{
          subject.ensure_service_instance(deploy_rev)
        }.to change{service_instance.reload.deploy_rev}.from(old_rev).to(deploy_rev)

        service_instance = grid_service.grid_service_instances.first

        expect(service_instance.instance_number).to eq instance_number
        expect(service_instance.host_node).to eq node
        expect(service_instance.deploy_rev).to eq deploy_rev
        expect(service_instance.desired_state).to eq 'running'
      end
    end
  end

  context "With an existing deployed instance on a different host node" do
    let(:old_rev) { 1.hours.ago.utc.to_s }
    let(:old_node) { HostNode.create!(name: "old-node", node_id: SecureRandom.uuid) }

    let(:service_instance) {
      grid_service.grid_service_instances.create!(
        instance_number: instance_number,
        deploy_rev: old_rev,
        host_node: old_node,
      )
    }

    before do
      service_instance
    end

    describe '#stop_service_instance' do
      it "stops the old instance" do
        expect(subject).to receive(:deploy_service_instance).with(service_instance, old_node, deploy_rev, 'stopped')

        subject.stop_service_instance(service_instance, deploy_rev)
      end

      it "warns if it fails" do
        expect(subject).to receive(:deploy_service_instance).and_raise(RpcClient::TimeoutError.new(503, "Connection timeout (2s)"))

        expect(subject).to receive(:warn).with("Failed to stop existing service test-grid/null/redis-2 on previous node old-node: Connection timeout (2s)")

        subject.stop_service_instance(service_instance, deploy_rev)
      end
    end

    describe '#ensure_service_instance' do
      it "stops the old instance and deploys the new one" do
        expect(subject).to receive(:stop_service_instance).with(service_instance, deploy_rev).and_call_original

        expect(subject).to receive(:deploy_service_instance).once.with(service_instance, old_node, deploy_rev, 'stopped')
        expect(subject).to receive(:deploy_service_instance).once.with(service_instance, node, deploy_rev, 'running').and_call_original
        expect(subject).to receive(:notify_node).with(node)
        expect(subject).to receive(:wait_until!).with("service test-grid/null/redis-2 is running on node /node at #{deploy_rev}", timeout: 300) do
          grid_service.grid_service_instances.first.set(rev: deploy_rev, state: 'running')
        end

        expect{
          subject.ensure_service_instance(deploy_rev)
        }.to change{service_instance.reload.host_node}.from(old_node).to(node)

        service_instance = grid_service.grid_service_instances.first

        expect(service_instance.instance_number).to eq instance_number
        expect(service_instance.host_node).to eq node
        expect(service_instance.deploy_rev).to eq deploy_rev
        expect(service_instance.desired_state).to eq 'running'
      end
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
      expect(volume_scheduler).to receive(:deploy).with(node, grid_service.service_volumes[0], instance_number)
      subject.ensure_volume_instance
    end
  end
end
