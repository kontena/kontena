require_relative '../spec_helper'

describe Grid do
  it { should be_timestamped_document }
  it { should have_fields(:name, :token)}

  it { should have_and_belong_to_many(:users) }
  it { should have_many(:host_nodes) }
  it { should have_many(:grid_services) }
  it { should have_many(:containers) }
  it { should have_many(:container_logs) }
  it { should have_many(:container_stats) }
  it { should have_many(:audit_logs) }


  it { should have_index_for(token: 1).with_options(unique: true) }
end