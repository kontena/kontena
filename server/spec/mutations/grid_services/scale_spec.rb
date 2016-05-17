require_relative '../../spec_helper'

describe GridServices::Scale do
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
  let(:redis_service) {
    GridService.create(
      grid: grid, name: 'redis', image_name: 'redis:2.8'
    )
  }
  let(:subject) {
    described_class.new(
      current_user: user, grid_service: redis_service, instances: 2
    )
  }

  describe '#run' do
    it 'sends deploy call to worker' do
      expect {
        subject.run
      }.to change{ redis_service.grid_service_deploys.count }.by(1)
    end

    it 'updates container_count' do
      redis_service # create
      expect {
        subject.run
      }.to change{ redis_service.reload.container_count }.from(1).to(2)
    end

    it 'sets state to deploy_pending' do
      expect {
        subject.run
      }.to change{ redis_service.reload.deploy_pending? }.from(false).to(true)
    end
  end
end
