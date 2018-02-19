describe StackDeploy do
  it { should be_timestamped_document }
  it { should belong_to(:stack) }
  it { should have_many(:grid_service_deploys) }

  it { should have_index_for(stack_id: 1) }

  let(:grid) { Grid.create!(name: 'test-grid')}
  let(:stack) { grid.stacks.create!(name: 'test-stack') }
  subject { described_class.create!(stack: stack) }

  context "without any service deploys" do
    it "is not started_at" do
      expect(subject.started_at).to be nil
    end

    it "is not finished_at" do
      expect(subject.finished_at).to be nil
    end

    it "is created" do
      expect(subject.state).to eq :created
    end
  end

  context "with one stack service" do
    let!(:service) { grid.grid_services.create(name: 'test-service', image_name: 'redis:latest') }

    context "with a created service deploy" do
      let!(:service_deploy) { GridServiceDeploy.create!(grid_service: service, stack_deploy: subject,
        deploy_state: :created,
      ) }

      it "is not started_at" do
        expect(subject.started_at).to be nil
      end

      it "is not finished_at" do
        expect(subject.finished_at).to be nil
      end

      it "is ongoing" do
        expect(subject.state).to eq :ongoing
      end
    end

    context "with a started service deploy" do
      let!(:service_deploy) { GridServiceDeploy.create!(grid_service: service, stack_deploy: subject,
        started_at: Time.now.utc - 10.0,
        deploy_state: :ongoing,
      ) }

      it "is started_at" do
        expect(subject.started_at).to eq service_deploy.started_at
      end

      it "is not finished_at" do
        expect(subject.finished_at).to be nil
      end

      it "is ongoing" do
        expect(subject.state).to eq :ongoing
      end
    end

    context "with a finished service deploy" do
      let!(:service_deploy) { GridServiceDeploy.create!(grid_service: service, stack_deploy: subject,
        started_at: Time.now.utc - 30.0,
        finished_at: Time.now.utc - 10.0,
        deploy_state: :success,
      ) }

      it "is started_at" do
        expect(subject.started_at).to eq service_deploy.started_at
      end

      it "is finished_at" do
        expect(subject.finished_at).to eq service_deploy.finished_at
      end

      it "is success" do
        expect(subject.state).to eq :success
      end
    end

    context "with a failed service deploy" do
      let!(:service_deploy) { GridServiceDeploy.create!(grid_service: service, stack_deploy: subject,
        started_at: Time.now.utc - 30.0,
        finished_at: Time.now.utc - 10.0,
        deploy_state: :error,
      ) }

      it "is started_at" do
        expect(subject.started_at).to eq service_deploy.started_at
      end

      it "is finished_at" do
        expect(subject.finished_at).to eq service_deploy.finished_at
      end

      it "is error" do
        expect(subject.state).to eq :error
      end
    end
  end

  context "with two stack services" do
    let!(:service1) { grid.grid_services.create(name: 'test-service1', image_name: 'redis:latest') }
    let!(:service2) { grid.grid_services.create(name: 'test-service2', image_name: 'redis:latest') }

    context "with created service deploys" do
      let!(:service1_deploy) { GridServiceDeploy.create!(grid_service: service1, stack_deploy: subject,
        deploy_state: :created,
      ) }
      let!(:service2_deploy) { GridServiceDeploy.create!(grid_service: service2, stack_deploy: subject,
        deploy_state: :created,
      ) }

      it "is not started_at" do
        expect(subject.started_at).to be nil
      end

      it "is not finished_at" do
        expect(subject.finished_at).to be nil
      end

      it "is ongoing" do
        expect(subject.state).to eq :ongoing
      end
    end

    context "with a errored+created service deploy" do
      let!(:service1_deploy) { GridServiceDeploy.create!(grid_service: service1, stack_deploy: subject,
        started_at: Time.now.utc - 30.0,
        finished_at: Time.now.utc - 10.0,
        deploy_state: :error,
      ) }
      let!(:service2_deploy) { GridServiceDeploy.create!(grid_service: service2, stack_deploy: subject,
        deploy_state: :created,
      ) }

      it "is started_at" do
        expect(subject.started_at).to eq service1_deploy.started_at
      end

      it "is not finished_at" do
        expect(subject.finished_at).to be nil
      end

      it "is error" do
        expect(subject.state).to eq :error
      end
    end

    context "with a finished+started service deploy" do
      let!(:service1_deploy) { GridServiceDeploy.create!(grid_service: service1, stack_deploy: subject,
        started_at: Time.now.utc - 30.0,
        finished_at: Time.now.utc - 10.0,
        deploy_state: :success,
      ) }
      let!(:service2_deploy) { GridServiceDeploy.create!(grid_service: service2, stack_deploy: subject,
        started_at: Time.now.utc - 10.0,
        deploy_state: :ongoing,
      ) }

      it "is started_at" do
        expect(subject.started_at).to eq service1_deploy.started_at
      end

      it "is not finished_at" do
        expect(subject.finished_at).to be nil
      end

      it "is ongoing" do
        expect(subject.state).to eq :ongoing
      end
    end

    context "with a finished+error service deploy" do
      let!(:service1_deploy) { GridServiceDeploy.create!(grid_service: service1, stack_deploy: subject,
        started_at: Time.now.utc - 30.0,
        finished_at: Time.now.utc - 10.0,
        deploy_state: :success,
      ) }
      let!(:service2_deploy) { GridServiceDeploy.create!(grid_service: service2, stack_deploy: subject,
        started_at: Time.now.utc - 10.0,
        finished_at: Time.now.utc - 5.0,
        deploy_state: :error,
      ) }

      it "is started_at" do
        expect(subject.started_at).to eq service1_deploy.started_at
      end

      it "is finished_at" do
        expect(subject.finished_at).to eq service2_deploy.finished_at
      end

      it "is error" do
        expect(subject.state).to eq :error
      end
    end

    context "with a finished+finished service deploy" do
      let!(:service1_deploy) { GridServiceDeploy.create!(grid_service: service1, stack_deploy: subject,
        started_at: Time.now.utc - 30.0,
        finished_at: Time.now.utc - 10.0,
        deploy_state: :success,
      ) }
      let!(:service2_deploy) { GridServiceDeploy.create!(grid_service: service2, stack_deploy: subject,
        started_at: Time.now.utc - 10.0,
        finished_at: Time.now.utc - 5.0,
        deploy_state: :success,
      ) }

      it "is started_at" do
        expect(subject.started_at).to eq service1_deploy.started_at
      end

      it "is finished_at" do
        expect(subject.finished_at).to eq service2_deploy.finished_at
      end

      it "is success" do
        expect(subject.state).to eq :success
      end
    end
  end
end
