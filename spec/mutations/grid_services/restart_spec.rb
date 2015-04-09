require_relative '../../spec_helper'

describe GridServices::Restart do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }
  let(:restarter) { spy(:restarter) }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}

  describe '#run' do
    it 'sends restart to restarter for each container' do
      allow(restarter).to receive(:restart_container)
      redis_service.containers.create!(name: 'redis-1-volume', container_id: '12', container_type: 'volume')
      container = redis_service.containers.create!(name: 'redis-1', container_id: '34')
      subject = described_class.new(current_user: user, grid_service: redis_service)
      expect(subject).to receive(:restarter_for).with(container).once.and_return(restarter)
      subject.run
    end

    it 'sets service state to running' do
      allow(restarter).to receive(:restart_container)
      redis_service.containers.create!(name: 'redis-1', container_id: '34')
      subject = described_class.new(current_user: user, grid_service: redis_service)
      allow(subject).to receive(:restarter_for).and_return(restarter)
      subject.run
      expect(redis_service.state).to eq('running')
    end

    it 'returns service to previous state if exception is raised' do
      prev_state = redis_service.state
      redis_service.containers.create!(name: 'redis-1', container_id: '34')
      subject = described_class.new(current_user: user, grid_service: redis_service)
      expect(subject).to receive(:restarter_for).and_raise(StandardError.new('error'))
      expect {
        subject.run
      }.to raise_exception
      expect(redis_service.state).to eq(prev_state)
    end
  end

  describe '#restarter_for' do
    it 'returns Docker::ContainerRestarter' do
      container = redis_service.containers.create!(name: 'redis-1', container_id: '34')
      subject = described_class.new(current_user: user, grid_service: redis_service)
      expect(subject.restarter_for(container)).to be_instance_of(Docker::ContainerRestarter)
    end
  end
end