
describe GridServices::Scale, celluloid: true do
  let(:grid) { Grid.create!(name: 'test-grid', initial_size: 1) }
  let(:host_node) { grid.create_node!('test-node', node_id: 'aa') }
  let(:redis_service) {
    GridService.create(
      grid: grid, name: 'redis', image_name: 'redis:2.8'
    )
  }
  let(:subject) {
    described_class.new(
      grid_service: redis_service, instances: 2
    )
  }

  describe '#run' do
    it 'creates a grid service deploy' do
      expect {
        subject.run
      }.to change{ redis_service.grid_service_deploys.count }.by(1)
    end

    it 'does not change service revision' do
      expect{
        subject.run!
      }.to_not change{redis_service.reload.revision}
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

    it 'returns deploy object in a result' do
      outcome = subject.run
      expect(outcome.result).to be_instance_of(GridServiceDeploy)
    end
  end
end
