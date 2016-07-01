require_relative '../spec_helper'

describe GridServiceDeploy do
  it { should be_timestamped_document }
  it { should have_fields(:started_at, :finished_at).of_type(DateTime) }
  it { should belong_to(:grid_service) }
  it { should have_index_for(grid_service_id: 1) }
  it { should have_index_for(created_at: 1) }
  it { should have_index_for(started_at: 1) }
end
