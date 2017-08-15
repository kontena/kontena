
describe GridScheduler do

  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:nodes) do
    (1..3).map { |i|
      grid.create_node!("node-#{i + 1}",
        node_id: SecureRandom.uuid,
        connected: true,
      )
    }
  end
  let(:service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid, container_count: 2) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(grid) }


  describe '#should_reschedule_service?' do
    before(:each) { nodes }

    it 'returns false to stateful service' do
      service.set(stateful: true, state: 'running')
      expect(subject.should_reschedule_service?(service)).to be_falsey
    end

    context "for a running stateless service" do
      before do
        service.set(stateful: false, state: 'running')
      end

      it 'returns true to stateless service' do
        expect(subject.should_reschedule_service?(service)).to be_truthy
      end

      it 'returns false if service has pending deploys' do
        service.grid_service_deploys.create!
        expect(subject.should_reschedule_service?(service)).to be_falsey
      end

      it 'returns false if service has active deploys' do
        service.grid_service_deploys.create(started_at: 5.minutes.ago)
        expect(subject.should_reschedule_service?(service)).to be_falsey
      end

      it 'returns true if service has only finished deploys' do
        service.grid_service_deploys.create(started_at: 5.minutes.ago, finished_at: 4.minutes.ago, deploy_state: :success)
        expect(subject.should_reschedule_service?(service)).to be_truthy
      end

      it 'returns true if service has only stale deploys' do
        service.grid_service_deploys.create(started_at: 1.hour.ago)
        expect(subject.should_reschedule_service?(service)).to be_truthy
      end

    end
  end

  describe '#all_instances_exist?' do
    context 'all nodes are disconnected' do
      it 'returns always true' do
        HostNode.all.each { |n| n.set(connected: false) }
        expect(subject.all_instances_exist?(service)).to be_truthy
      end
    end

    context 'all nodes are connected' do
      before(:each) { nodes }

      it 'returns false if no instances exist' do
        expect(subject.all_instances_exist?(service)).to be_falsey
      end

      it 'returns false if only instances exist only partially' do
        service.grid_service_instances.create!(
          host_node: nodes[1],
          instance_number: 1,
          deploy_rev: Time.now.to_s
        )
        expect(subject.all_instances_exist?(service)).to be_falsey
      end

      it 'returns true if all instances exist' do
        deploy_rev = Time.now.to_s
        2.times do |i|
          service.grid_service_instances.create!(
            host_node: nodes[i],
            instance_number: i + 1,
            deploy_rev: deploy_rev
          )
        end
        expect(subject.all_instances_exist?(service)).to be_truthy
      end

      it 'returns false if too many instances exist' do
        4.times do |i|
          service.grid_service_instances.create!(
            host_node: nodes[i],
            instance_number: i,
            deploy_rev: Time.now.to_s
          )
        end
        expect(subject.all_instances_exist?(service)).to be_falsey
      end
    end

    context 'some nodes are disconnected' do
      before(:each) do
        nodes[1].set(connected: false)
      end

      let(:strategy) { Scheduler::Strategy::HighAvailability.new }

      it 'returns false if node is offline and not seen' do
        2.times do |i|
          service.grid_service_instances.create!(
            host_node: nodes[i],
            instance_number: i + 1,
            deploy_rev: Time.now.to_s
          )
        end
        expect(subject.all_instances_exist?(service)).to be_falsey
      end

      it 'returns false if node is offline and outside grace period' do
        nodes[1].set(connected: false, last_seen_at: (strategy.host_grace_period + 2.seconds).ago)
        2.times do |i|
          service.grid_service_instances.create!(
            host_node: nodes[i],
            instance_number: i + 1,
            deploy_rev: Time.now.to_s
          )
        end
        expect(subject.all_instances_exist?(service)).to be_falsey
      end

      it 'returns true if node is offline and within grace period' do
        nodes[1].set(connected: false, last_seen_at: (10.seconds).ago)
        2.times do |i|
          service.grid_service_instances.create!(
            host_node: nodes[i],
            instance_number: i + 1,
            deploy_rev: Time.now.to_s
          )
        end
        expect(subject.all_instances_exist?(service)).to be_truthy
      end
    end

    context 'some nodes are missing' do
      it 'returns false if node is missing' do
        2.times do |i|
          service.grid_service_instances.create!(
            host_node: nodes[i],
            instance_number: i + 1,
            deploy_rev: Time.now.to_s
          )
        end
        nodes[1].destroy

        expect(subject.all_instances_exist?(service)).to be_falsey
      end

      it 'returns true if node is missing outside scheduled nodes' do
        2.times do |i|
          service.grid_service_instances.create!(
            host_node: nodes[i],
            instance_number: i + 1,
            deploy_rev: Time.now.to_s
          )
        end
        nodes[2].destroy

        expect(subject.all_instances_exist?(service)).to be_truthy
      end
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
