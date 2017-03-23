
describe GridServices::Deploy, celluloid: true do
  let(:host_node) { HostNode.create(node_id: 'aa')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid', initial_size: 1)
    grid.host_nodes << host_node
    grid
  }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}
  let(:subject) { described_class.new(grid_service: redis_service, strategy: 'ha')}

  describe '#run' do
    it 'does not allow to deploy service that is starting' do
      redis_service.set_state('starting')
      outcome = subject.run
      expect(outcome.success?).to be_falsey
      expect(outcome.errors.message['state']).not_to be_nil
    end

    it 'does not allow to deploy service that is stopping' do
      redis_service.set_state('stopping')
      outcome = subject.run
      expect(outcome.success?).to be_falsey
      expect(outcome.errors.message['state']).not_to be_nil
    end

    it 'allows to deploy service that is initialized' do
      redis_service.set_state('initialized')
      outcome = subject.run
      expect(outcome.success?).to be_truthy
      expect(redis_service.reload.running?).to be_truthy
    end

    it 'allows to deploy service that is running' do
      redis_service.set_state('running')
      outcome = subject.run
      expect(outcome.success?).to be_truthy
      expect(redis_service.reload.running?).to be_truthy
    end

    it 'allows to deploy service that is deploying' do
      redis_service.grid_service_deploys.create!(started_at: Time.now)
      outcome = subject.run
      expect(outcome.success?).to be_truthy
      expect(redis_service.reload.deploying?).to be_truthy
    end

    it 'allows to deploy service that is stopped' do
      redis_service.set_state('stopped')
      outcome = subject.run
      expect(outcome.success?).to be_truthy
      expect(redis_service.reload.running?).to be_truthy
    end

    it 'sends deploy call to worker' do
      grid
      expect {
        subject.run
      }.to change{ redis_service.grid_service_deploys.count }.by(1)
    end

    it 'updates deploy_requested_at' do
      expect {
        subject.run
      }.to change{ redis_service.reload.deploy_requested_at }
    end

    it 'sets state to deploy_pending' do
      expect {
        subject.run
      }.to change{ redis_service.reload.deploy_pending? }.from(false).to(true)
    end

    it 'sets deploy to result' do
      outcome = subject.run
      expect(outcome.result).to be_instance_of(GridServiceDeploy)
    end
  end
end
