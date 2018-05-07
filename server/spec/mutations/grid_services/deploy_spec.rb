
describe GridServices::Deploy, celluloid: true do
  let(:grid) { Grid.create!(name: 'test-grid', initial_size: 1) }
  let(:host_node) { grid.create_node!('test-node', node_id: 'aa') }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}
  let(:subject) { described_class.new(grid_service: redis_service)}

  describe '#run' do
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

    it 'creates service deploy' do
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
      expect(outcome).to be_success

      deploy = outcome.result
      expect(deploy).to be_instance_of(GridServiceDeploy)
      expect(deploy.grid_service).to eq redis_service
    end
  end
end
