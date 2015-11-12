require_relative '../../spec_helper'

describe GridServices::Start do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }
  let(:starter) { spy(:starter) }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}
  let(:subject) { described_class.new(current_user: user, grid_service: redis_service)}

  describe '#run' do
    it 'starts service containers' do
      redis_service.containers.create!(name: 'redis-1-volume', container_id: '12', container_type: 'volume')
      container = redis_service.containers.create!(name: 'redis-1', container_id: '34')
      allow(starter).to receive(:start_container)
      allow(subject).to receive(:starter_for).with(container).once.and_return(starter)

      subject.run
    end

    it 'sets service state to running' do
      allow(starter).to receive(:start_container)
      redis_service.containers.create!(name: 'redis-1', container_id: '34')
      allow(subject).to receive(:starter_for).and_return(starter)
      subject.run
      expect(redis_service.state).to eq('running')
    end

    it 'returns service to previous state if exception is raised' do
      prev_state = redis_service.state
      redis_service.containers.create!(name: 'redis-1', container_id: '34')
      subject = described_class.new(current_user: user, grid_service: redis_service)
      expect(subject).to receive(:start_service_instance).and_raise(StandardError.new('error'))
      expect {
        subject.run
      }.to raise_exception
      expect(redis_service.state).to eq(prev_state)
    end
  end
end
