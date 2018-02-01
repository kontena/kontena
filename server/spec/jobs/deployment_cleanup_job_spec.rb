
describe DeploymentCleanupJob, celluloid: true do

  let(:grid) { Grid.create!(name: 'test-grid') }

  let(:service) do
    GridService.create!(name: 'test', image_name: 'test:latest', grid: grid)
  end

  let(:another_service) do
    GridService.create!(name: 'another', image_name: 'test:latest', grid: grid)
  end

  let(:subject) { described_class.new(false) }

  describe '#cleanup_old_deployments' do
    it 'destroys deployments older than 100th one' do
      200.times do |i|
        # Use the reason field to track the sequence
        service.grid_service_deploys.create!(finished_at: Time.now.utc, reason: (i + 1).to_s)
      end
      expect {
        subject.destroy_old_deployments
      }.to change{ GridServiceDeploy.count }.by(-100)
      deploys = service.reload.grid_service_deploys.finished.desc('_id').to_a
      expect(deploys.first.reason).to eq(200.to_s)
      expect(deploys.last.reason).to eq(101.to_s)
    end

    it 'destroys nothing if less than 100 deployments' do
      # #destroy_old_deployments should not be even called with less than 100 deployments, but just to make sure...
      99.times do |i|
        # Use the reason field to track the sequence
        service.grid_service_deploys.create!(finished_at: Time.now.utc, reason: (i + 1).to_s)
      end
      expect {
        subject.destroy_old_deployments
      }.not_to change{ GridServiceDeploy.count }
    end
  end

  describe '#destroy_old_deployments' do
    it 'cleans deployments if more than 100 finished ones' do
      200.times do |i|
        # Use the reason field to track the sequence
        service.grid_service_deploys.create!(finished_at: Time.now.utc, reason: (i + 1).to_s)
      end
      expect(subject.wrapped_object).to receive(:cleanup_old_deployments).with(service)
      subject.destroy_old_deployments
    end

    it 'destroys nothing if less than 100 deployments' do
      99.times do |i|
        # Use the reason field to track the sequence
        service.grid_service_deploys.create!(finished_at: Time.now.utc, reason: (i + 1).to_s)
      end
      expect(subject.wrapped_object).not_to receive(:cleanup_old_deployments)
      subject.destroy_old_deployments
    end

    it 'destroys nothing if no deployments' do
      service
      expect(subject.wrapped_object).not_to receive(:cleanup_old_deployments)
      subject.destroy_old_deployments
    end

  end
end
