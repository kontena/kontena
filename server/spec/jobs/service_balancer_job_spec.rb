
describe ServiceBalancerJob, celluloid: true do
  before(:each) { DistributedLock.delete_all }

  let(:grid) { Grid.create(name: 'test')}
  let(:service) do
    GridService.create!(
      name: 'redis',
      image_name: 'redis:latest',
      grid: grid,
      state: 'running',
      created_at: 5.minutes.ago,
      updated_at: 4.minutes.ago
    )
  end

  describe '#should_balance_service?' do
    context 'stateful' do
      before(:each) do
        service.stateful = true
      end

      it 'returns false by default' do
        expect(subject.should_balance_service?(service)).to be_falsey
      end
    end

    context 'stateless' do
      it 'returns true by default' do
        expect(subject.should_balance_service?(service)).to be_truthy
      end

      it 'returns false if there are pending deploys' do
        service.grid_service_deploys.create!
        expect(subject.should_balance_service?(service)).to be_falsey
      end

      it 'returns true if deployed and not all instances exist' do
        service.deployed_at = 3.minutes.ago
        allow(service).to receive(:all_instances_exist?).and_return(false)
        expect(subject.should_balance_service?(service)).to be_truthy
      end

      it 'returns false if all instances exist' do
        allow(subject.wrapped_object).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_falsey
      end

      it 'returns true if deployed in past, instances exist and deploy has been requested' do
        service.deployed_at = 3.minutes.ago
        service.deploy_requested_at = 2.minutes.ago
        allow(service).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_truthy
      end

      it 'returns true if deployed and interval time has gone' do
        service.deployed_at = 3.minutes.ago
        service.deploy_opts.interval = 120
        allow(subject.wrapped_object).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_truthy
      end

      it 'returns false if deployed and interval time has not gone' do
        service.deployed_at = 3.minutes.ago
        service.deploy_opts.interval = 60 * 60
        allow(subject.wrapped_object).to receive(:all_instances_exist?).and_return(true)
        expect(subject.should_balance_service?(service)).to be_falsey
      end
    end
  end

  describe '#all_instances_exist?' do
    before(:each) do
      service.set(container_count: 2)
    end

    context 'default' do
      it 'returns true if all instances exist' do
        2.times{|i| service.containers.create!(name: "test-#{i}", state: {running: true}) }
        expect(subject.all_instances_exist?(service)).to eq(true)
      end

      it 'returns false if not all instances are running' do
        service.containers.create!(name: "test-1", state: {running: true})
        service.containers.create!(name: "test-2", state: {running: false})
        expect(subject.all_instances_exist?(service)).to eq(false)
      end

      it 'returns false if service has too many instances' do
        service.containers.create!(name: "test-1", state: {running: true})
        service.containers.create!(name: "test-1", state: {running: true})
        service.containers.create!(name: "test-2", state: {running: true})
        expect(subject.all_instances_exist?(service)).to eq(false)
      end

      it 'returns true if containers are marked as deleted and are within grace period' do
        service.containers.create!(
          name: "test-1", state: {running: true}, deleted_at: 5.seconds.ago
        )
        service.containers.create!(
          name: "test-2", state: {running: true}, deleted_at: 50.seconds.ago
        )
        expect(subject.all_instances_exist?(service)).to eq(true)
      end
    end

    context 'daemon strategy' do
      let(:nodes) do
        nodes = []
        nodes << HostNode.create!(name: "node-1", grid: grid, connected: true)
        nodes << HostNode.create!(name: "node-2", grid: grid, connected: false)
        nodes
      end

      before(:each) do
        nodes
        service.set(strategy: 'daemon')
      end

      it 'returns true if all instances exist' do
        2.times{|i| service.containers.create!(name: "test-#{i}", state: {running: true}) }
        expect(subject.all_instances_exist?(service)).to eq(true)
      end

      it 'returns false if not all instances exist within grace period' do
        nodes.each{|n| n.set(connected: true)}

        service.containers.create!(
          name: "test-1", state: {running: true}, host_node: nodes[0]
        )
        service.containers.create!(
          name: "test-2", state: {running: true},
          host_node: nodes[1], deleted_at: 10.minutes.ago
        )
        service.containers.create!(
          name: "test-3", state: {running: true},
          host_node: nodes[2], deleted_at: 7.minutes.ago
        )
        service.containers.create!(
          name: "test-4", state: {running: true},
          host_node: nodes[3]
        )
        expect(subject.all_instances_exist?(service)).to eq(false)
      end

      it 'returns true if all instances exist within grace period' do
        service.containers.create!(
          name: "test-1", state: {running: true}, host_node: nodes[0]
        )
        service.containers.create!(
          name: "test-2", state: {running: true},
          host_node: nodes[1]
        )
        service.containers.create!(
          name: "test-3", state: {running: true},
          host_node: nodes[2], deleted_at: 1.minutes.ago
        )
        service.containers.create!(
          name: "test-4", state: {running: true},
          host_node: nodes[3], deleted_at: 1.minutes.ago
        )
        expect(subject.all_instances_exist?(service)).to eq(true)
      end
    end
  end

  describe '#deploy_alive?' do
    it 'returns false by default' do
      expect(subject.deploy_alive?(service)).to be_falsey
    end

    it 'returns true if deployer responds to ping' do
      channel = "grid_service_deployer:#{service.id}"
      subscription = MongoPubsub.subscribe(channel) do |event|
        MongoPubsub.publish(channel, event: 'pong')
      end
      expect(subject.deploy_alive?(service)).to be_truthy
    end
  end

  describe '#pending_deploys?' do
    it 'returns false by default' do
      expect(subject.pending_deploys?(service)).to be_falsey
    end

    it 'returns true if pending deploys' do
      service.grid_service_deploys.create!
      expect(subject.pending_deploys?(service)).to be_truthy
    end
  end

  describe '#active_deploys?' do
    it 'returns false by default' do
      expect(subject.active_deploys?(service)).to be_falsey
    end

    it 'returns true if service has active deploys' do
      service.grid_service_deploys.create(started_at: 5.minutes.ago)
      expect(subject.active_deploys?(service)).to be_truthy
    end

    it 'returns false if service has only finished deploys' do
      service.grid_service_deploys.create(started_at: 5.minutes.ago, deploy_state: :success)
      expect(subject.active_deploys?(service)).to be_falsey
    end

    it 'returns false if service has only stale deploys' do
      service.grid_service_deploys.create(started_at: 1.hour.ago)
      expect(subject.active_deploys?(service)).to be_falsey
    end
  end

  describe '#active_deploys_within_stack?' do
    it 'returns false by default' do
      expect(subject.active_deploys_within_stack?(service)).to be_falsey
    end

    it 'returns true if service has active deploys' do
      service.stack.stack_deploys.create
      expect(subject.active_deploys_within_stack?(service)).to be_truthy
    end

    it 'returns false if service has only finished deploys' do
      service.stack.stack_deploys.create(deploy_state: :success)
      expect(subject.active_deploys_within_stack?(service)).to be_falsey
    end

    it 'returns false if service has only stale deploys' do
      service.stack.stack_deploys.create(created_at: 1.hour.ago)
      expect(subject.active_deploys_within_stack?(service)).to be_falsey
    end
  end

  describe '#lagging_behind?' do
    it 'returns false by default' do
      expect(subject.lagging_behind?(service)).to be_falsey
    end

    it 'returns true if service has been updated since last deploy' do
      service.set(updated_at: Time.now.utc, deployed_at: 5.minutes.ago)
      expect(subject.lagging_behind?(service)).to be_truthy
    end

    it 'returns false if service has not been updated since last deploy' do
      service.set(updated_at: 5.minutes.ago, deployed_at: Time.now.utc)
      expect(subject.lagging_behind?(service)).to be_falsey
    end
  end

  describe '#interval_passed?' do
    it 'returns false by default' do
      expect(subject.lagging_behind?(service)).to be_falsey
    end

    it 'returns false if interval is set and last deploy time has not passed interval' do
      service.deploy_opts.interval = 120
      service.set(deployed_at: 1.minute.ago)
      expect(subject.interval_passed?(service)).to be_falsey
    end

    it 'returns true if interval is set and last deploy time has passed interval' do
      service.deploy_opts.interval = 60
      service.set(deployed_at: 5.minutes.ago)
      expect(subject.interval_passed?(service)).to be_truthy
    end
  end
end
