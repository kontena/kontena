require_relative '../spec_helper'

describe GridService do
  it { should be_timestamped_document }
  it { should have_fields(:image_name, :name, :user, :entrypoint, :state,
                          :net, :log_driver).of_type(String) }
  it { should have_fields(:container_count, :memory,
                          :memory_swap, :cpu_shares).of_type(Fixnum) }
  it { should have_fields(:affinity, :cmd, :ports, :env, :volumes, :volumes_from,
                          :cap_add, :cap_drop, :volumes).of_type(Array) }
  it { should have_fields(:labels, :log_opts).of_type(Hash) }
  it { should have_fields(:privileged).of_type(Mongoid::Boolean) }

  it { should belong_to(:grid) }
  it { should embed_many(:grid_service_links) }
  it { should embed_one(:deploy_opts) }
  it { should have_many(:containers) }
  it { should have_many(:container_logs) }
  it { should have_many(:container_stats) }
  it { should have_many(:audit_logs) }


  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_service_ids: 1) }

  let(:grid) do
    Grid.create(name: 'test-grid')
  end

  let(:grid_service) do
    GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8')
  end

  describe '#stateful?' do
    it 'returns true if stateful' do
      subject.stateful = true
      expect(subject.stateful?).to eq(true)
    end

    it 'returns false if not stateful' do
      subject.stateful = false
      expect(subject.stateful?).to eq(false)
    end
  end

  describe '#stateless?' do
    it 'returns true if stateless' do
      subject.stateful = false
      expect(subject.stateless?).to eq(true)
    end

    it 'returns false if not stateless' do
      subject.stateful = true
      expect(subject.stateless?).to eq(false)
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

  describe '#all_instances_exist?' do
    before(:each) do
      subject.attributes = {name: 'test', image_name: 'foo/bar:latest'}
      subject.container_count = 2
      subject.save!
    end

    it 'returns true if all instances exist' do
      2.times{|i| subject.containers.create!(name: "test-#{i}") }
      expect(subject.all_instances_exist?).to eq(true)
    end

    it 'returns false if not all instances exist' do
      1.times{|i| subject.containers.create!(name: "test-#{i}") }
      expect(subject.all_instances_exist?).to eq(false)
    end
  end

  describe '#set_state' do
    it 'sets value of state column' do
      subject.set_state('running')
      expect(subject.state).to eq('running')
    end

    it 'does not modify updated_at field' do
      five_hours_ago = Time.now.utc - 5.hours
      grid_service.timeless.update_attribute(:updated_at, five_hours_ago)
      grid_service.clear_timeless_option
      grid_service.set_state('running')
      expect(grid_service.updated_at).to eq(five_hours_ago)
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
end
