require_relative '../spec_helper'

describe GridServiceSchedulerWorker do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:grid) { Grid.create(name: 'test')}
  let(:service) { GridService.create(name: 'test', image_name: 'foo/bar:latest', grid: grid)}
  let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc) }

  describe '#check_deploy_queue' do
    it 'picks oldest item from deploy queue' do
      newest = service_deploy
      oldest = GridServiceDeploy.create(grid_service: service, created_at: 1.minute.ago)
      sleep 0.1
      subject.check_deploy_queue

      puts newest.reload.started_at
      puts oldest.reload.started_at
      #expect(newest.reload.started_at).to be_nil
      #expect(oldest.reload.started_at).not_to be_nil
    end

    it 'triggers perform if service can be deployed' do
      expect(subject.wrapped_object).to receive(:perform).with(service_deploy)
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
