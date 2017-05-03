
describe GridServiceDeploy do
  it { should be_timestamped_document }
  it { should have_fields(:started_at, :finished_at).of_type(DateTime) }
  it { should have_fields(:reason).of_type(String) }
  it { should belong_to(:grid_service) }
  it { should belong_to(:stack_deploy) }

  it { should have_index_for(grid_service_id: 1).with_options(background: true) }
  it { should have_index_for(created_at: 1).with_options(background: true) }
  it { should have_index_for(started_at: 1).with_options(background: true) }

  describe '#deploy_type' do
    it 'defaults to automatic' do
      expect(subject.deploy_type).to eq(:automatic)
    end
  end
end
