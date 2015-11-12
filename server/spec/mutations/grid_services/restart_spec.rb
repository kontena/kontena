require_relative '../../spec_helper'

describe GridServices::Restart do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}
  let(:node) { HostNode.create!(name: 'node-1', grid: grid)}

  describe '#run' do
    it 'sends restart' do
      container = redis_service.containers.create!(
        name: 'redis-1', container_id: '34', host_node: node
      )
      subject = described_class.new(current_user: user, grid_service: redis_service)
      expect(subject).to receive(:restart_service_instance).with(node, container.name).once
      subject.run
    end

    it 'sets service state to running' do
      redis_service.containers.create!(name: 'redis-1', container_id: '34')
      subject = described_class.new(current_user: user, grid_service: redis_service)
      allow(:subject).to receive(:restart_service_instance)
      subject.run
      expect(redis_service.state).to eq('running')
    end

    it 'returns service to previous state if exception is raised' do
      prev_state = redis_service.state
      redis_service.containers.create!(name: 'redis-1', container_id: '34')
      subject = described_class.new(current_user: user, grid_service: redis_service)
      expect(subject).to receive(:restart_service_instances).and_raise(StandardError.new('error'))
      outcome = subject.run
      outcome.result.value
      expect(redis_service.state).to eq(prev_state)
    end
  end
end
