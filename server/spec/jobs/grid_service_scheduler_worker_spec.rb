
describe GridServiceSchedulerWorker, celluloid: true do

  let(:grid) { Grid.create(name: 'test')}
  let(:service) { GridService.create(name: 'test', image_name: 'foo/bar:latest', grid: grid)}
  let(:subject) { described_class.new(false) }

  describe '#watch' do
    let(:deployer) { instance_double(GridServiceDeployer) }

    before do
      allow(subject.wrapped_object).to receive(:loop) do |&block| block.call end
      allow(subject.wrapped_object).to receive(:sleep)
      allow(GridServiceDeployer).to receive(:new).and_return(deployer)
    end

    it "does nothing if no queued deploys" do
      expect(subject.wrapped_object).to_not receive(:deploy)
      subject.watch
    end

    it "runs created deploys" do
      service_deploy = GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc)

      expect(deployer).to receive(:deploy)

      subject.watch
    end

    it "does not run finished deploys" do
      service_deploy = GridServiceDeploy.create(grid_service: service, created_at: 1.hour.ago, queued_at: 1.hour.ago, started_at: 1.hour.ago, finished_at: 1.hour.ago)

      expect(deployer).to_not receive(:deploy)

      subject.watch
    end
  end

  describe '#check_deploy_queue' do
    it "returns nil if fetch_deploy_item returns nil" do
      expect(subject.wrapped_object).to receive(:fetch_deploy_item).and_return(nil)

      expect(subject.check_deploy_queue).to be_nil
    end

    it "fails if fetch_deploy_item returns a non-pending deploy" do
      service_deploy = GridServiceDeploy.create(grid_service: service, created_at: 1.hour.ago, started_at: 1.hour.ago)

      expect(subject.check_deploy_queue).to be_nil
      expect(service_deploy.reload).to be_finished
      expect(service_deploy.reason).to eq "service deploy aborted: deploy not pending"
    end

    it "aborts deploy when un-handled error occurs" do
      service_deploy = GridServiceDeploy.create(grid_service: nil, created_at: 1.hour.ago)
      expect(subject.wrapped_object).to receive(:fetch_deploy_item).and_return(service_deploy)

      expect(subject.check_deploy_queue).to be_nil
      expect(service_deploy.reload).to be_aborted
      expect(service_deploy.deploy_state).to eq :error
      expect(service_deploy.reason).not_to be_nil
    end

  end

  context "without any deploys" do
    describe 'service' do
      it "is not deploying" do
        expect(service).to_not be_deploying
      end
      it "is not deploy_pending" do
        expect(service).to_not be_deploy_pending
      end
      it "is not deploy_running" do
        expect(service).to_not be_deploy_running
      end
    end

    describe '#fetch_deploy_item' do
      it 'returns nil' do
        expect(subject.fetch_deploy_item).to be_nil
      end
    end

    describe '#check_deploy_queue' do
      it 'returns nil' do
        expect(subject.check_deploy_queue).to be_nil
      end
    end
  end

  context "with a single created deploy" do
    let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc) }

    before do
      service_deploy
    end

    describe 'service' do
      it "is deploying" do
        expect(service).to be_deploying
      end
      it "is deploy_pending" do
        expect(service).to be_deploy_pending
      end
      it "is not deploy_running" do
        expect(service).to_not be_deploy_running
      end
    end

    describe '#fetch_deploy_item' do
      it "queues and returns deploy" do
        expect{
          expect(subject.fetch_deploy_item).to eq service_deploy
        }.to change{service_deploy.reload.queued_at}.from(nil).to(a_value >= 1.second.ago)

        expect(service).to be_deploy_pending
      end
    end

    describe '#check_deploy_queue' do
      it "starts and returns the deploy" do
        expect{
          expect(subject.check_deploy_queue).to eq service_deploy
        }.to change{service_deploy.reload.started_at}.from(nil).to(a_value >= 1.second.ago)

        expect(service).to_not be_deploy_pending
        expect(service).to be_deploy_running
      end
    end
  end

  context "with multiple created deploys" do
    let(:oldest_deploy) { GridServiceDeploy.create(grid_service: service, created_at: 2.minutes.ago) }
    let(:newest_deploy) { GridServiceDeploy.create(grid_service: service, created_at: 1.minutes.ago) }

    before do
      oldest_deploy
      newest_deploy
    end

    describe '#fetch_deploy_item' do
      it 'queues and returns oldest item from deploy queue' do
        expect(subject.fetch_deploy_item).to eq oldest_deploy
        expect(newest_deploy.reload).to_not be_queued
        expect(oldest_deploy.reload).to be_queued
      end
    end
  end

  context "with a single recently queued deploy" do
    let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc, queued_at: Time.now.utc) }

    before do
      service_deploy
    end

    describe 'service' do
      it "is deploying" do
        expect(service).to be_deploying
      end
      it "is deploy_pending" do
        expect(service).to be_deploy_pending
      end
      it "is not deploy_running" do
        expect(service).to_not be_deploy_running
      end
    end

    describe '#fetch_deploy_item' do
      it 'returns nil' do
        expect(subject.fetch_deploy_item).to be_nil
      end
    end
  end

  context "with an expired queued deploy" do
    let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc, queued_at: 1.minute.ago) }

    before do
      service_deploy
    end

    describe 'service' do
      it "is deploying" do
        expect(service).to be_deploying
      end
      it "is deploy_pending" do
        expect(service).to be_deploy_pending
      end
      it "is not deploy_running" do
        expect(service).to_not be_deploy_running
      end
    end

    describe '#fetch_deploy_item' do
      it 're-queues and returns deploy' do
        expect{
          expect(subject.fetch_deploy_item).to eq service_deploy
        }.to change{service_deploy.reload.queued_at}.from(a_value <= 1.minute.ago).to(a_value >= 1.second.ago)

        expect(service).to be_deploy_pending
      end
    end
  end

  context "with a single running deploy" do
    let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc, :queued_at => 1.minute.ago, :started_at => 30.seconds.ago) }

    before do
      service_deploy
    end

    describe 'service' do
      it "is deploying" do
        expect(service).to be_deploying
      end
      it "is not deploy_pending" do
        expect(service).to_not be_deploy_pending
      end
      it "is deploy_running" do
        expect(service).to be_deploy_running
      end
    end

    describe '#fetch_deploy_item' do
      it 'ignores deploy' do
        expect{
          expect(subject.fetch_deploy_item).to be_nil
        }.to not_change{service_deploy.reload.queued_at}
      end
    end
  end

  context "with one queued and one running deploy" do
    let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc) }
    let(:running_deploy) { GridServiceDeploy.create(grid_service: service, created_at: 1.minute.ago, :queued_at => 2.seconds.ago, :started_at => 1.seconds.ago) }

    before do
      service_deploy
      running_deploy
    end

    describe 'service' do
      it "is deploying" do
        expect(service).to be_deploying
      end
      it "is deploy_pending" do
        expect(service).to be_deploy_pending
      end
      it "is deploy_running" do
        expect(service).to be_deploy_running
      end
    end

    describe '#fetch_deploy_item' do
      it "queues and returns deploy" do
        expect{
          expect(subject.fetch_deploy_item).to eq service_deploy
        }.to change{service_deploy.reload.queued_at}.from(nil).to(a_value >= 1.second.ago)

        expect(service).to be_deploy_pending
      end
    end

    describe '#check_deploy_queue' do
      it "leaves deploy queued" do
        expect{
          expect(subject.check_deploy_queue).to be_nil
        }.to not_change{service_deploy.reload.started_at}.and not_change{running_deploy.reload.started_at}

        expect(service_deploy).to_not be_running
        expect(service).to be_deploy_pending
      end
    end
  end

  context "with a created deploy for a stopped service" do
    let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc) }

    before do
      service_deploy
      service.set_state('stopped')
    end

    describe '#check_deploy_queue' do
      it "starts and returns the deploy" do
        expect{
          expect(subject.check_deploy_queue).to eq service_deploy
        }.to change{service_deploy.reload.started_at}.from(nil).to(a_value >= 1.second.ago)

        expect(service).to_not be_deploy_pending
        expect(service).to be_deploy_running
      end
    end
  end

  context "for an aborted deploy" do
    let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: 1.minute.ago, :queued_at => 1.minute.ago) }

    before do
      service_deploy
      service_deploy.abort! 'testing'
    end

    describe 'service' do
      it "is not deploying" do
        expect(service).to_not be_deploying
      end
      it "is not deploy_pending" do
        expect(service).to_not be_deploy_pending
      end
      it "is not deploy_running" do
        expect(service).to_not be_deploy_running
      end
    end

    describe '#fetch_deploy_item' do
      it "ignores the deploy" do
        expect{
          expect(subject.fetch_deploy_item).to be_nil
        }.to not_change{service_deploy.reload.queued_at}
      end
    end
  end

  context "for an timeout deploy" do
    let(:timeout_deploy) { GridServiceDeploy.create(grid_service: service, created_at: 60.minutes.ago, queued_at: 40.minutes.ago, started_at: 30.minutes.ago) }

    before do
      timeout_deploy
    end

    describe 'service' do
      it "is not deploying" do
        expect(service).to_not be_deploying
      end
      it "is not deploy_pending" do
        expect(service).to_not be_deploy_pending
      end
      it "is not deploy_running" do
        expect(service).to_not be_deploy_running
      end
    end

    describe '#fetch_deploy_item' do
      it "ignores the deploy" do
        expect{
          expect(subject.fetch_deploy_item).to be_nil
        }.to not_change{timeout_deploy.reload.queued_at}
      end
    end

    context "with a newer created deploy" do
      let(:created_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc) }

      before do
        created_deploy
      end

      describe 'service' do
        it "is deploying" do
          expect(service).to be_deploying
        end
        it "is deploy_pending" do
          expect(service).to be_deploy_pending
        end
        it "is not deploy_running" do
          expect(service).to_not be_deploy_running
        end
      end

      describe '#check_deploy_queue' do
        it "starts and returns the deploy" do
          expect{
            expect(subject.check_deploy_queue).to eq created_deploy
          }.to change{created_deploy.reload.started_at}.from(nil).to(a_value >= 1.second.ago)

          expect(service).to_not be_deploy_pending
          expect(service).to be_deploy_running
        end
      end
    end
  end

  describe '#deploy' do
    let(:service_deploy) { GridServiceDeploy.create(grid_service: service, created_at: Time.now.utc) }

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
  end
end
