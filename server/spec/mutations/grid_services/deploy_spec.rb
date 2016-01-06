require_relative '../../spec_helper'

describe GridServices::Deploy do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:host_node) { HostNode.create(node_id: 'aa')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid', initial_size: 1)
    grid.users << user
    grid.host_nodes << host_node
    grid
  }
  let(:worker) { spy(:worker) }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}
  let(:subject) { described_class.new(current_user: user, grid_service: redis_service, strategy: 'ha')}

  describe '#run' do
    it 'sends deploy call to worker' do
      grid
      expect(subject).to receive(:worker).with(:grid_service_scheduler).once.and_return(worker)
      expect(worker).to receive(:perform).once.with(redis_service.id)
      subject.run
    end

    it 'updates deploy_requested_at' do
      allow(subject).to receive(:worker).with(:grid_service_scheduler).once.and_return(worker)
      expect {
        subject.run
      }.to change{ redis_service.reload.deploy_requested_at }
    end
  end
end
