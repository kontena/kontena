
describe Container do
  it { should be_timestamped_document }
  it { should have_fields(
        :container_id, :name, :driver,
        :exec_driver, :image, :image_version,
        :hostname, :domainname).of_type(String) }
  it { should have_fields(:instance_number).of_type(Integer) }
  it { should have_fields(:env, :volumes, :cmd).of_type(Array) }
  it { should have_fields(:network_settings, :state, :labels).of_type(Hash) }
  it { should have_fields(:finished_at, :started_at).of_type(Time) }

  it { should validate_uniqueness_of(:container_id).scoped_to(:host_node_id) }

  it { should belong_to(:grid) }
  it { should belong_to(:grid_service) }
  it { should belong_to(:host_node) }
  it { should have_many(:container_logs) }
  it { should have_many(:container_stats) }

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_service_id: 1) }
  it { should have_index_for(host_node_id: 1) }
  it { should have_index_for(container_id: 1) }
  it { should have_index_for(state: 1) }
  it { should have_index_for(instance_number: 1) }

  let(:grid) do
    Grid.create(name: 'test-grid')
  end

  let(:grid_service) do
    service = GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8')
    service.image = image
    service
  end

  let(:image) do
    Image.create(image_id: '12345', name: 'redis:2.8')
  end

  describe '#status' do
    it 'returns deleted when deleted_at timestamp is set' do
      subject.deleted_at = Time.now.utc
      expect(subject.status).to eq('deleted')
    end

    it 'returns paused if docker state is paused' do
      subject.updated_at = Time.now
      subject.state['paused'] = true
      expect(subject.status).to eq('paused')
    end

    it 'returns stopped if docker state is stopped' do
      subject.updated_at = Time.now
      subject.state['stopped'] = true
      expect(subject.status).to eq('stopped')
    end

    it 'returns running if docker state is running' do
      subject.updated_at = Time.now
      subject.state['running'] = true
      expect(subject.status).to eq('running')
    end

    it 'returns running if docker state is running and oom_killed' do
      subject.updated_at = Time.now
      subject.state['running'] = true
      subject.state['oom_killed'] = true
      expect(subject.status).to eq('running')
    end

    it 'returns restarting if docker state is restarting' do
      subject.updated_at = Time.now
      subject.state['restarting'] = true
      expect(subject.status).to eq('restarting')
    end

    it 'returns oom_killed if docker state is oom_killed' do
      subject.updated_at = Time.now
      subject.state['oom_killed'] = true
      expect(subject.status).to eq('oom_killed')
    end

    it 'returns dead if docker state is dead' do
      subject.updated_at = Time.now
      subject.state['dead'] = true
      expect(subject.status).to eq('dead')
    end

    it 'returns stopped otherwise' do
      subject.updated_at = Time.now
      expect(subject.status).to eq('stopped')
    end
  end

  describe '#up_to_date?' do
    context 'when image id differs from grid service image id' do
      it 'returns false ' do
        subject.grid_service = grid_service

        grid_service.image.image_id = '12345'
        subject.image_version = '1234567'
        expect(subject.up_to_date?).to be_falsey
      end
    end

    context 'when grid service is updated after container is created' do
      it 'returns false' do
        subject.grid_service = grid_service
        grid_service.timeless.updated_at = Time.now.utc + 3
        subject.created_at = Time.now.utc
        expect(subject.up_to_date?).to be_falsey
      end
    end

    context 'when image is not updated and container is created after last update of grid service' do
      it 'return false' do
        subject.grid_service = grid_service
        subject.image_version = '12345'
        grid_service.timeless.updated_at = Time.now.utc - 3
        subject.created_at = Time.now.utc
        expect(subject.up_to_date?).to be_truthy
      end
    end
  end

  describe '#instance_name' do
    it 'does not throw error by default' do
      expect(subject.instance_name).to be_instance_of(String)
    end

    it 'returns correct name for instance' do
      subject.instance_number = 3
      subject.labels = {
        'io;kontena;service;name' => 'redis',
        'io;kontena;stack;name' => 'null'
      }
      expect(subject.instance_name).to eq('null-redis-3')
    end
  end

  describe '#label' do
    it 'returns label value if label exists' do
      subject.labels = { 'io;kontena;service;name' => 'redis' }
      expect(subject.label('io.kontena.service.name')).to eq('redis')
    end

    it 'returns nil if label does not exist' do
      subject.labels = { 'io;kontena;service;name' => 'redis' }
      expect(subject.label('io.kontena.service.id')).to be_nil
    end
  end

  describe '#set_health_status' do
    it 'updates health_status' do
      subject.health_status = 'Not healthy'
      subject.set_health_status('Healthy')
      expect(subject.health_status).to eq('Healthy')
    end

    it 'updates health_status_at' do
      subject.health_status = 'Not healthy'
      last_updated = Time.now - 2.seconds
      subject.health_status_at = last_updated
      subject.set_health_status('Healthy')
      expect(subject.health_status_at).not_to eq(last_updated)
    end

    it 'triggers publish_update_event if health status changes' do
      subject.health_status = 'Not healthy'
      expect(subject).to receive(:publish_update_event).once
      subject.set_health_status('Healthy')
    end

    it 'does not trigger publish_update_event if health status does not change' do
      subject.health_status = 'Healthy'
      expect(subject).not_to receive(:publish_update_event)
      subject.set_health_status('Healthy')
    end
  end

  describe '.service_instance' do
    it 'returns correct instance' do
      (1..3).each do |i|
        grid_service.containers.create!(
          name: "redis-#{i}",
          instance_number: i
        )
      end

      container = described_class.service_instance(grid_service, 2).first
      expect(container.name).to eq("redis-2")
    end
  end

  describe 'counts_for_grid_services' do
    let(:redis) do
      GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8')
    end
    let(:nginx) do
      GridService.create!(grid: grid, name: 'nginx', image_name: 'nginx')
    end

    it 'returns correct count per service' do
      (1..3).each do |i|
        redis.containers.create!(
          grid: grid,
          name: "redis-#{i}",
          instance_number: i,
          container_type: 'container'
        )
        redis.containers.create!(
          grid: grid,
          name: "redis-#{i}-volumes",
          instance_number: i,
          container_type: 'volume'
        )
      end
      (1..3).each do |i|
        nginx.containers.create!(
          grid: grid,
          name: "nginx-#{i}",
          instance_number: i,
          container_type: 'container'
        )
      end
      expect(described_class.counts_for_grid_services(grid.id)).to include(
        {'_id' => redis.id, 'total' => 3},
        {'_id' => nginx.id, 'total' => 3}
      )
    end
  end
end
