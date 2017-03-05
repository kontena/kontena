
describe HostNodeStat do
  it { should be_timestamped_document }
  it { should have_fields(:memory, :load, :usage, :cpu_average).of_type(Hash)}
  it { should have_fields(:filesystem).of_type(Array)}

  it { should belong_to(:grid) }
  it { should belong_to(:host_node) }

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(host_node_id: 1) }
  it { should have_index_for(created_at: 1) }
end
