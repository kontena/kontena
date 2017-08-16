describe GridServices::Start do
  include AsyncMock

  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid
  }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}
  let(:subject) { described_class.new(grid_service: redis_service)}

  describe '#run' do
    it 'starts service containers' do
      redis_service.containers.create!(name: 'redis-1-volume', container_id: '12', container_type: 'volume')
      container = redis_service.containers.create!(name: 'redis-1', container_id: '34')
      expect(subject).to receive(:start_service_instances).and_return(true)

      outcome = subject.run
    end

    it 'sets service state to running' do
      redis_service.containers.create!(name: 'redis-1', container_id: '34')
      allow(subject).to receive(:start_service_instances).and_return(true)
      outcome = subject.run
      expect(redis_service.reload.state).to eq('running')
    end

    it 'returns service to previous state if exception is raised' do
      prev_state = redis_service.state
      redis_service.containers.create!(name: 'redis-1', container_id: '34')
      subject = described_class.new(grid_service: redis_service)
      expect(subject).to receive(:start_service_instances).and_raise(StandardError.new('error'))
      expect {
        outcome = subject.run
      }.to raise_exception(StandardError)
      expect(redis_service.state).to eq(prev_state)
    end
  end
end
