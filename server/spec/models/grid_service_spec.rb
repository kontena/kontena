require_relative '../spec_helper'

describe GridService do
  it { should be_timestamped_document }
  it { should have_fields(:image_name, :name, :user, :entrypoint, :state,
                          :net, :log_driver).of_type(String) }
  it { should have_fields(:container_count, :memory,
                          :memory_swap, :cpu_shares).of_type(Fixnum) }
  it { should have_fields(:affinity, :cmd, :ports, :env, :volumes, :volumes_from,
                          :cap_add, :cap_drop, :volumes).of_type(Array) }
  it { should have_fields(:labels, :deploy_opts, :log_opts).of_type(Hash) }
  it { should have_fields(:privileged).of_type(Mongoid::Boolean) }

  it { should belong_to(:grid) }
  it { should embed_many(:grid_service_links) }
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
end
