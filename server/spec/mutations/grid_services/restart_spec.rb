
describe GridServices::Restart, celluloid: true do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}
  let(:node) { HostNode.create!(name: 'node-1', grid: grid)}

  describe '#run' do
    it 'sends restart' do
      container = redis_service.containers.create!(
        name: 'redis-1', container_id: '34', host_node: node, instance_number: 1
      )
      subject = described_class.new(grid_service: redis_service)
      expect(subject).to receive(:restart_service_instance).with(node, container.instance_number).once
      subject.run.result.value
    end

    it 'sets service state to running' do
      redis_service.containers.create!(name: 'redis-1', container_id: '34')
      subject = described_class.new(grid_service: redis_service)
      allow(subject).to receive(:restart_service_instance)
      outcome = subject.run
      outcome.result.value
      expect(redis_service.state).to eq('running')
    end

    it 'returns service to previous state if exception is raised' do
      prev_state = redis_service.state
      redis_service.containers.create!(name: 'redis-1', container_id: '34')
      subject = described_class.new(grid_service: redis_service)
      expect(subject).to receive(:restart_service_instance).and_raise(StandardError.new('error'))
      outcome = subject.run
      expect(outcome.success?).to be_truthy
      expect {
        outcome.result.value
      }.to raise_exception(StandardError)
      expect(redis_service.state).to eq(prev_state)
    end
  end
end
