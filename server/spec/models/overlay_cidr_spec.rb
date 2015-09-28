require_relative '../spec_helper'

describe OverlayCidr do
  it { should have_fields(:ip, :subnet).of_type(String) }
  it { should belong_to(:container) }
  it { should belong_to(:grid) }

  it { should have_index_for(container_id: 1) }
  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_id: 1, ip: 1, subnet: 1).with_options({unique: true}) }
end
