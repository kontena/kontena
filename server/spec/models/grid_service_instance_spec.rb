require_relative '../spec_helper'

describe GridServiceInstance do
  it { should have_fields(:desired_state, :state, :deploy_rev, :rev).of_type(String) }
  it { should have_fields(:instance_number).of_type(Integer) }

  it { should belong_to(:grid_service) }
  it { should belong_to(:host_node) }

  it { should have_index_for(grid_service_id: 1) }
  it { should have_index_for(host_node_id: 1) }
end
