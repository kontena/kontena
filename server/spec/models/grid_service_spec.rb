describe GridService do
  it { should be_timestamped_document }
  it { should be_kind_of(EventStream) }
  it { should have_fields(:image_name, :name, :user, :entrypoint, :state,
                          :net, :log_driver, :pid).of_type(String) }
  it { should have_fields(:container_count, :memory,
                          :memory_swap, :cpu_shares,
                          :revision, :stack_revision, :shm_size).of_type(Integer) }
  it { should have_fields(:affinity, :cmd, :ports, :env, :volumes_from,
                          :cap_add, :cap_drop).of_type(Array) }
  it { should have_fields(:labels, :log_opts).of_type(Hash) }
  it { should have_fields(:deploy_requested_at, :deployed_at).of_type(DateTime) }
  it { should have_fields(:privileged).of_type(Mongoid::Boolean) }

  it { should belong_to(:grid) }
  it { should belong_to(:stack) }
  it { should embed_many(:grid_service_links) }
  it { should embed_many(:secrets) }
  it { should embed_many(:hooks) }
  it { should embed_many(:service_volumes) }
  it { should embed_one(:deploy_opts) }
  it { should have_many(:containers) }
  it { should have_many(:container_logs) }
  it { should have_many(:container_stats) }
  it { should have_many(:audit_logs) }
  it { should have_many(:grid_service_instances) }
  it { should have_many(:grid_service_deploys) }
  it { should have_many(:event_logs) }

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:image_name) }
  it { should validate_presence_of(:grid_id) }
  it { should validate_presence_of(:stack_id) }

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_service_ids: 1) }

  let(:grid) do
    Grid.create(name: 'test-grid')
  end
  let :stack do
    Stack.create(grid: grid, name: 'stack')
  end

  let(:grid_service) do
    GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8')
  end
  let(:stack_service) do
    GridService.create!(grid: grid, stack: stack, name: 'redis', image_name: 'redis:2.8')
  end

  let(:stacked_service) do
    stack = Stack.create!(name: 'stack')
    GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8', stack: stack)
  end

  describe '#qualified_name' do
    it 'returns full path for stacked service' do
      expect(stacked_service.qualified_name).to eq("#{stacked_service.stack.name}/#{stacked_service.name}")
    end

    it 'returns path without stack for stackless service' do
      expect(grid_service.qualified_name).to eq("#{grid_service.name}")
    end
  end

  describe '#stateful?' do
    it 'returns true if stateful' do
      subject.stateful = true
      expect(subject.stateful?).to be_truthy
    end

    it 'returns false if not stateful' do
      subject.stateful = false
      expect(subject.stateful?).to be_falsey
    end
  end

  describe '#stateless?' do
    it 'returns true if stateless' do
      subject.stateful = false
      expect(subject.stateless?).to be_truthy
    end

    it 'returns false if not stateless' do
      subject.stateful = true
      expect(subject.stateless?).to be_falsey
    end
  end

  describe '#daemon?' do
    it 'returns true if strategy is daemon' do
      subject.strategy = 'daemon'
      expect(subject.daemon?).to be_truthy
    end

    it 'returns false if strategy is not daemon' do
      expect(subject.daemon?).to be_falsey
    end
  end

  describe '#running?' do
    it 'returns true if service is running' do
      subject.state = 'running'
      expect(subject.running?).to eq(true)
    end

    it 'returns false if service is not running' do
      subject.state = 'stopped'
      expect(subject.running?).to eq(false)
    end
  end

  describe '#stopped?' do
    it 'returns true if service is stopped' do
      subject.state = 'stopped'
      expect(subject.stopped?).to eq(true)
    end

    it 'returns false if service is not stopped' do
      subject.state = 'running'
      expect(subject.stopped?).to eq(false)
    end
  end

  describe '#set_state' do
    it 'sets value of state column' do
      grid_service.set_state('running')
      expect(grid_service.state).to eq('running')
    end

    it 'does not modify updated_at field' do
      five_hours_ago = Time.now.utc - 5.hours
      grid_service.timeless.update_attribute(:updated_at, five_hours_ago)
      grid_service.clear_timeless_option
      grid_service.set_state('running')
      expect(grid_service.updated_at).to eq(five_hours_ago)
    end

    it 'publishes update event' do
      expect(grid_service).to receive(:publish_update_event).once
      grid_service.set_state('running')
    end
  end

  describe '#container_by_name' do
    it 'returns related container by name' do
      container = grid_service.containers.create!(name: 'redis-1')
      expect(grid_service.container_by_name(container.name)).to eq(container)
    end

    it 'returns nil if container is not found' do
      expect(grid_service.container_by_name('not_found')).to be_nil
    end
  end

  describe '#dependant_services' do
    let(:subject) { grid_service }

    it 'returns dependant by volumes_from' do
      backupper = GridService.create!(
        grid: grid, name: 'backupper',
        image_name: 'backupper:latest', volumes_from: ["#{subject.name}-%s"]
      )
      follower = GridService.create!(
        grid: grid, name: 'follower',
        image_name: 'follower:latest', volumes_from: ["#{subject.name}-1"]
      )
      dependant_services = subject.dependant_services
      expect(dependant_services.size).to eq(2)
      expect(dependant_services).to include(backupper)
      expect(dependant_services).to include(follower)
    end

    it 'returns dependant services by service affinity' do
      avoider = GridService.create!(
        grid: grid, name: 'avoider',
        image_name: 'avoider:latest',
        affinity: ["service!=#{subject.name}"]
      )
      follower = GridService.create!(
        grid: grid, name: 'follower',
        image_name: 'follower:latest',
        affinity: ["service==#{subject.name}"]
      )
      dependant_services = subject.dependant_services
      expect(dependant_services.size).to eq(2)
      expect(dependant_services).to include(avoider)
      expect(dependant_services).to include(follower)
    end
  end

  describe '#linked_from_services' do
    it 'returns Mongoid::Criteria' do
      expect(grid_service.linked_from_services).to be_instance_of(Mongoid::Criteria)
    end

    it 'returns services that service has been linked from' do
      a = GridService.create!(
        grid: grid, name: 'aaa', image_name: 'aaa:latest',
        grid_service_links: [
          GridServiceLink.new(linked_grid_service_id: grid_service.id, alias: 'foo')
        ]
      )
      b = GridService.create!(
        grid: grid, name: 'bbb', image_name: 'bbb:latest',
        grid_service_links: [
          GridServiceLink.new(linked_grid_service_id: a.id, alias: 'a-foo')
        ]
      )
      expect(grid_service.linked_from_services.count).to eq(1)
      expect(grid_service.linked_from_services.first.id).to eq(a.id)
      expect(a.linked_from_services.count).to eq(1)
      expect(a.linked_from_services.first.id).to eq(b.id)
    end
  end

  describe '#load_balancer?' do
    it 'returns true if latest official kontena/lb image' do
      subject.image_name = 'kontena/lb:latest'
      expect(subject.load_balancer?).to eq(true)
    end

    it 'returns true if official kontena/lb image' do
      subject.image_name = 'kontena/lb:edge'
      expect(subject.load_balancer?).to eq(true)
    end

    it 'returns true if custom image with KONTENA_SERVICE_ROLE=lb env variable' do
      subject.image_name = 'custom/lb:latest'
      subject.env << 'KONTENA_SERVICE_ROLE=lb'
      expect(subject.load_balancer?).to eq(true)
    end

    it 'returns false if not official kontena/lb image' do
      subject.image_name = 'acme/lb:latest'
      expect(subject.load_balancer?).to eq(false)
    end

    it 'returns false by default' do
      expect(subject.load_balancer?).to eq(false)
    end
  end

  describe '#health_status' do
    it 'returns health status' do
      healthy_container = grid_service.containers.create!(name: 'redis-1')
      healthy_container.update_attribute(:health_status, 'healthy')
      unhealthy_container = grid_service.containers.create!(name: 'redis-2')
      unhealthy_container.update_attribute(:health_status, 'unhealthy')

      expect(grid_service.health_status).to eq({healthy: 1, unhealthy: 1, total: 2})
    end

    it 'returns nil if container is not found' do
      expect(grid_service.container_by_name('not_found')).to be_nil
    end
  end

  describe '#name_with_stack' do
    it 'returns stackless service name without stack' do
      expect(grid_service.name_with_stack).to eq 'redis'
    end
    it 'returns stack service name with stack' do
      expect(stack_service.name_with_stack).to eq 'stack.redis'
    end
  end

  describe '#stack_exposed?' do
    it 'returns true if service is exposed via stack' do
      stack = Stack.create!(name: 'redis')
      stack.stack_revisions.create(expose: 'redis')
      service = GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8', stack: stack)
      expect(service.stack_exposed?).to be_truthy
    end

    it 'returns false if service is not exposed via stack' do
      expect(grid_service.stack_exposed?).to be_falsey
    end
  end

  describe '#depending_on_other_services?' do
    it 'returns false by default' do
      expect(subject.depending_on_other_services?).to be_falsey
    end

    it 'returns true if service affinity' do
      subject.affinity = ['service==foobar']
      expect(subject.depending_on_other_services?).to be_truthy
      subject.affinity = ['service!=foobar']
      expect(subject.depending_on_other_services?).to be_truthy
    end

    it 'returns true if volumes_from' do
      subject.volumes_from = ['foobar-%i']
      expect(subject.depending_on_other_services?).to be_truthy
    end
  end

  describe '#affinity' do
    it 'returns empty array by default' do
      expect(subject.affinity).to eq([])
    end

    it 'returns service affinity if set' do
      subject.grid = grid
      subject.affinity = ['label==foo=bar']
      expect(subject.affinity).to eq(['label==foo=bar'])
    end

    it 'returns default affinity from grid if service affinity is not set' do
      grid.default_affinity = ['label!=type=ssd']
      subject.grid = grid
      expect(subject.affinity).to eq(['label!=type=ssd'])
    end
  end

  describe '#env_hash' do
    it 'should build a valid hash' do
      expect(subject).to receive(:env).and_return(
        [
          'FOO=bar',
          'FOO=BAR=bar',
          'BAR=',
          'DOG'
        ]
      )
      expect(subject.env_hash).to eq(
        {
          'FOO' => 'BAR=bar',
          'BAR' => '',
          'DOG' => nil
        }
      )
    end
  end

  describe '#deploying?' do
    it 'returns false when no deployments' do
      expect(subject.deploying?).to be_falsey
    end

    it 'returns true when queued deployments' do
      GridServiceDeploy.create!(grid_service: subject, started_at: nil, finished_at: nil)
      expect(subject.deploying?).to be_truthy
    end

    it 'returns true when un-finished deployments' do
      GridServiceDeploy.create!(grid_service: subject, started_at: 10.minutes.ago, finished_at: nil)
      expect(subject.deploying?).to be_truthy
    end

    it 'returns false when un-finished stale deployments' do
      GridServiceDeploy.create!(grid_service: subject, started_at: 32.minutes.ago, finished_at: nil)
      expect(subject.deploying?).to be_falsey
    end

    it 'returns false when finished deployments' do
      GridServiceDeploy.create!(grid_service: subject, started_at: 32.minutes.ago, finished_at: 26.minutes.ago)
      expect(subject.deploying?).to be_falsey
    end

    it 'returns false when finished deployments with no started_at' do
      GridServiceDeploy.create!(grid_service: subject, started_at: nil, finished_at: 26.minutes.ago)
      expect(subject.deploying?).to be_falsey
    end
  end
end
