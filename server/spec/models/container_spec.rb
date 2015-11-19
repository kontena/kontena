require_relative '../spec_helper'

describe Container do
  it { should be_timestamped_document }
  it { should have_fields(
        :container_id, :name, :driver,
        :exec_driver, :image, :image_version).of_type(String) }
  it { should have_fields(:env, :volumes).of_type(Array) }
  it { should have_fields(:network_settings, :state).of_type(Hash) }
  it { should have_fields(:finished_at, :started_at).of_type(Time) }

  it { should validate_uniqueness_of(:container_id).scoped_to(:host_node_id) }

  it { should belong_to(:grid) }
  it { should belong_to(:grid_service) }
  it { should belong_to(:host_node) }
  it { should have_one(:overlay_cidr) }
  it { should have_many(:container_logs) }
  it { should have_many(:container_stats) }

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_service_id: 1) }
  it { should have_index_for(host_node_id: 1) }
  it { should have_index_for(container_id: 1) }
  it { should have_index_for(state: 1) }

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

    it 'returns unknown if updated_at timestamp is far enough in the past' do
      subject.updated_at = Time.now.utc - 3.minutes
      expect(subject.status).to eq('unknown')
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
end
