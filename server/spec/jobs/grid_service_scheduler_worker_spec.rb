
describe GridServiceSchedulerWorker, celluloid: true do

  let(:grid) { Grid.create(name: 'test')}
  let(:service) { GridService.create(name: 'test', image_name: 'foo/bar:latest', grid: grid)}
  let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc) }
  let(:subject) { described_class.new(false) }

  describe '#fetch_deploy_item' do
    it 'returns nil if there are no deploys' do
      grid
      service

      expect(service).to_not be_deploy_pending
      expect(subject.fetch_deploy_item).to be_nil
    end

    it 'returns nil if the deploy is queued' do
      grid
      service
      service_deploy

      service_deploy.set(:queued_at => Time.now.utc)

      expect(service).to be_deploy_pending
      expect(subject.fetch_deploy_item).to be_nil
    end

    it 'queues and returns deploy if not yet queued' do
      grid
      service
      service_deploy

      expect{
        expect(subject.fetch_deploy_item).to eq service_deploy
      }.to change{service_deploy.reload.queued_at}.from(nil).to(a_value >= 1.second.ago)
      expect(service).to be_deploy_pending
    end

    it 'queues and returns oldest item from deploy queue' do
      newest = service_deploy
      oldest = GridServiceDeploy.create(grid_service: service, created_at: 1.minute.ago)

      expect(subject.fetch_deploy_item).to eq oldest
      expect(newest.reload.queued_at).to be_nil
      expect(oldest.reload.queued_at).not_to be_nil
    end

    it 're-queues and returns deploy if already queued but not yet started' do
      grid
      service
      service_deploy

      service_deploy.set(:queued_at => 1.minute.ago)

      expect{
        expect(subject.fetch_deploy_item).to eq service_deploy
      }.to change{service_deploy.reload.queued_at}.from(a_value <= 1.minute.ago).to(a_value >= 1.second.ago)
      expect(service).to be_deploy_pending
    end

    it 'does not return deploy if already started' do
      grid
      service
      service_deploy

      service_deploy.set(:queued_at => 1.minute.ago, :started_at => 30.seconds.ago)

      expect{
        expect(subject.fetch_deploy_item).to be_nil
      }.to not_change{service_deploy.reload.queued_at}
    end

    it 'does not return deploy if aborted' do
      grid
      service
      service_deploy

      service_deploy.set(:queued_at => 1.minute.ago)
      service_deploy.abort! 'testing'

      expect{
        expect(subject.fetch_deploy_item).to be_nil
      }.to not_change{service_deploy.reload.queued_at}
    end
  end

  context "with a single created deploy" do
    before do
      service_deploy # create
    end

    it "the service is deploying" do
      expect(service).to be_deploying
    end
    it "the service is deploy_pending" do
      expect(service).to be_deploy_pending
    end
    it "the service is not deploy_running" do
      expect(service).to_not be_deploy_running
    end

    describe '#check_deploy_queue' do
      it 'starts and returns the deploy' do
        expect{
          expect(subject.check_deploy_queue).to eq service_deploy
        }.to change{service_deploy.reload.started_at}.from(nil).to(a_value >= 1.second.ago)
      end
    end
  end

  context "with another running deploy" do
    let(:running_deploy) { service.grid_service_deploys.create!(queued_at: 2.seconds.ago, started_at: 1.second.ago) }

    before do
      service_deploy
      running_deploy
    end

    it "the service is deploying" do
      expect(service).to be_deploying
    end
    it "the service is deploy_pending" do
      expect(service).to be_deploy_pending
    end
    it "the service is deploy_running" do
      expect(service).to be_deploy_running
    end

    describe '#check_deploy_queue' do
      it "leaves deploy queued" do
        expect{
          expect(subject.check_deploy_queue).to be_nil
        }.to not_change{service_deploy.reload.started_at}.and not_change{running_deploy.reload.started_at}
      end
    end
  end

  context "for a stopped service" do
    before do
      service_deploy # create
      service.set_state('stopped')
    end

    it 'aborts deploy if service is stopped' do
      expect(subject.check_deploy_queue).to be_nil

      expect(service_deploy.reload).to be_abort
    end
  end

  describe '#deploy' do
    let(:deployer) { instance_double(GridServiceDeployer) }

    before do
      expect(subject.wrapped_object).to receive(:deployer).with(service_deploy).and_return(deployer)
    end

    it "runs deployer and marks deploy as finished_at" do
      expect(deployer).to receive(:deploy).once

      expect{
        subject.deploy(service_deploy)
      }.to change{service_deploy.reload.finished_at}.from(nil).to(a_value >= 1.second.ago)
    end

    it "runs deployer and marks deploy as finished_at on errors" do
      expect(deployer).to receive(:deploy).once.and_raise(RuntimeError, "testing")

      expect{
        subject.deploy(service_deploy)
      }.to raise_error(RuntimeError).and change{service_deploy.reload.finished_at}.from(nil).to(a_value >= 1.second.ago)
    end

    it "deploys dependent services" do
      expect(deployer).to receive(:deploy).once
      expect(subject.wrapped_object).to receive(:deploy_dependant_services).with(service)

      subject.deploy(service_deploy)
    end
  end

  context "with dependent services" do
    let(:dependent_service) {
      grid.grid_services.create(name: 'test2',
          image_name: 'foo/bar:latest',
          volumes_from: [
            'test-%s',
          ]
      )
    }

    before do
      dependent_service.link_to(service)

      expect(service.dependant_services).to eq [dependent_service]
    end

    describe '#deploy_dependant_services' do
      it "creates deploys for the dependent service" do
        subject.deploy_dependant_services(service_deploy.grid_service)

        expect(dependent_service).to be_deploying
      end
    end
  end
end
