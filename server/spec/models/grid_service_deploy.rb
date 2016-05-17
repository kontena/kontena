require_relative '../spec_helper'

describe GridServiceDeploy do
  it { should be_timestamped_document }
  it { should have_fields(:started_at, :finished_at).of_type(DateTime) }
  it { should belong_to(:grid_service) }
end
