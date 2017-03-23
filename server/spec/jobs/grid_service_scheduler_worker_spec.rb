
describe GridServiceSchedulerWorker, celluloid: true do

  let(:grid) { Grid.create(name: 'test')}
  let(:service) { GridService.create(name: 'test', image_name: 'foo/bar:latest', grid: grid)}
  let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc) }
  let(:subject) { described_class.new(false) }

  describe '#check_deploy_queue' do
    it 'picks oldest item from deploy queue' do
      newest = service_deploy
      oldest = GridServiceDeploy.create(grid_service: service, created_at: 1.minute.ago)
      subject.check_deploy_queue
      expect(newest.reload.started_at).to be_nil
      expect(oldest.reload.started_at).not_to be_nil
    end

    it 'removes deploy from queue if service is stopped' do
      service.set_state('stopped')
      deploy = service_deploy
      subject.check_deploy_queue
      expect(GridServiceDeploy.count).to eq(0)
    end

    it 'does not trigger deploy if service is already deploying' do
      service.grid_service_deploys.create!(started_at: Time.now)
      deploy = service_deploy
      expect(subject.wrapped_object).not_to receive(:deploy)
      subject.check_deploy_queue
      expect(GridServiceDeploy.count).to eq(2)
      expect(deploy.reload.started_at).not_to be_nil
    end

    it 'triggers perform if service can be deployed' do
      expect(subject.wrapped_object).to receive(:perform).with(service_deploy)
      subject.check_deploy_queue
    end

    it 'does not create deploy if service is stopped' do
      service.set_state('stopped')
      service_deploy # create
      expect(subject.wrapped_object).not_to receive(:perform)
      subject.check_deploy_queue
    end
  end

  describe '#perform' do
    it 'triggers deploy' do
      deployer = spy(:deployer)
      expect(deployer).to receive(:deploy).once
      expect(subject.wrapped_object).to receive(:deployer).with(service_deploy).and_return(deployer)
      subject.perform(service_deploy)
    end
  end
end
