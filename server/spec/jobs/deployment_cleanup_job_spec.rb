
describe DeploymentCleanupJob, celluloid: true do

  let(:grid) { Grid.create!(name: 'test-grid') }

  let(:service) do
    GridService.create!(name: 'test', image_name: 'test:latest', grid: grid)
  end

  let(:another_service) do
    GridService.create!(name: 'another', image_name: 'test:latest', grid: grid)
  end

  let(:subject) { described_class.new(false) }

  describe '#destroy_old_deployments' do
    it 'destroys deployments older than 100th one' do
      200.times do |i|
        # Use the reason field to track the sequence
        service.grid_service_deploys.create!(finished_at: Time.now.utc, reason: (i + 1).to_s)
      end
      expect {
        subject.destroy_old_deployments
      }.to change{ GridServiceDeploy.count }.by(-100)

      expect(service.reload.grid_service_deploys.finished.desc('_id').to_a.first.reason).to eq(200.to_s)
    end

    it 'destroys nothing if less than 100 deployments' do
      99.times do |i|
        # Use the reason field to track the sequence
        service.grid_service_deploys.create!(finished_at: Time.now.utc, reason: (i + 1).to_s)
      end
      expect {
        subject.destroy_old_deployments
      }.not_to change{ GridServiceDeploy.count }
    end

    it 'destroys nothing if no deployments' do
      service
      expect {
        subject.destroy_old_deployments
      }.not_to change{ GridServiceDeploy.count }
    end


    it 'destroys nothing if no finished deployments' do
      200.times do |i|
        # Use the reason field to track the sequence
        service.grid_service_deploys.create!(reason: (i + 1).to_s)
      end
      expect {
        subject.destroy_old_deployments
      }.not_to change{ GridServiceDeploy.count }
    end

    it 'destroys old deployments correctly for many services' do
      99.times do |i|
        # Use the reason field to track the sequence
        service.grid_service_deploys.create!(finished_at: Time.now.utc, reason: (i + 1).to_s)
      end
      200.times do |i|
        # Use the reason field to track the sequence
        another_service.grid_service_deploys.create!(finished_at: Time.now.utc, reason: (i + 1).to_s)
      end
      expect {
        subject.destroy_old_deployments
      }.to change{ GridServiceDeploy.count }.by(-100)
    end

  end
end
