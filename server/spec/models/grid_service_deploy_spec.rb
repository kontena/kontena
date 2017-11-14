describe GridServiceDeploy do
  it { should be_timestamped_document }
  it { should have_fields(:started_at, :finished_at).of_type(DateTime) }
  it { should have_fields(:reason).of_type(String) }
  it { should belong_to(:grid_service) }
  it { should belong_to(:stack_deploy) }

  it { should have_index_for(grid_service_id: 1).with_options(background: true) }
  it { should have_index_for(created_at: 1).with_options(background: true) }
  it { should have_index_for(started_at: 1).with_options(background: true) }
  it { should have_index_for(finished_at: 1).with_options(background: true) }

  let(:grid) { Grid.create(name: 'test')}
  let(:service) { grid.grid_services.create(name: 'test', image_name: 'foo/bar:latest')}

  context "for a created deploy" do
    subject { service.grid_service_deploys.create(created_at: Time.now.utc) }

    it "is pending" do
      expect(subject).to_not be_queued
      expect(subject).to be_pending
      expect(subject).to_not be_started
      expect(subject).to_not be_running
      expect(subject).to_not be_finished
    end
  end

  context "for a queued deploy" do
    subject { service.grid_service_deploys.create(created_at: Time.now.utc, queued_at: Time.now.utc) }

    it "is queued" do
      expect(subject).to be_queued
      expect(subject).to be_pending
      expect(subject).to_not be_started
      expect(subject).to_not be_running
      expect(subject).to_not be_finished
    end
  end

  context "for a started deploy" do
    subject { service.grid_service_deploys.create(created_at: Time.now.utc, queued_at: Time.now.utc, started_at: Time.now.utc) }

    it "is running" do
      expect(subject).to be_queued
      expect(subject).to_not be_pending
      expect(subject).to be_started
      expect(subject).to be_running
      expect(subject).to_not be_finished
    end
  end

  context "for a finished deploy" do
    subject { service.grid_service_deploys.create(created_at: 1.hour.ago, queued_at: 1.hour.ago, started_at: 1.hour.ago, finished_at: 50.minutes.ago) }

    it "is running" do
      expect(subject).to be_queued
      expect(subject).to_not be_pending
      expect(subject).to be_started
      expect(subject).to_not be_running
      expect(subject).to be_finished
      expect(subject).to_not be_timeout
    end
  end

  context "for an aborted deploy before starting" do
    subject { service.grid_service_deploys.create(created_at: Time.now.utc, queued_at: Time.now.utc) }

    before do
      subject.abort! "test"
    end

    it "is running" do
      expect(subject).to be_queued
      expect(subject).to_not be_pending
      expect(subject).to_not be_started
      expect(subject).to_not be_running
      expect(subject).to be_finished
    end

    it "is error" do
      expect(subject).to be_error
      expect(subject.reason).to eq "test"
    end
  end

  context "for an aborted deploy after starting" do
    subject { service.grid_service_deploys.create(created_at: Time.now.utc, queued_at: Time.now.utc, started_at: Time.now.utc) }

    before do
      subject.abort! "test"
    end

    it "is running" do
      expect(subject).to be_queued
      expect(subject).to_not be_pending
      expect(subject).to be_started
      expect(subject).to_not be_running
      expect(subject).to be_finished
    end

    it "is error" do
      expect(subject).to be_error
      expect(subject.reason).to eq "test"
    end
  end

  context "for an timed out deploy" do
    subject { service.grid_service_deploys.create(created_at: 1.hour.ago, queued_at: 1.hour.ago, started_at: 1.hour.ago) }

    it "is running" do
      expect(subject).to be_queued
      expect(subject).to_not be_pending
      expect(subject).to be_started
      expect(subject).to_not be_running
      expect(subject).to_not be_finished
      expect(subject).to be_timeout
    end
  end
end
