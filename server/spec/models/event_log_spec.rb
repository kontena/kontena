describe EventLog do
  it { should have_fields(:created_at).of_type(Time) }
  it { should have_fields(:type, :msg).of_type(String) }
  it { should have_fields(:severity).of_type(Integer) }

  it { should belong_to(:grid) }
  it { should belong_to(:stack) }
  it { should belong_to(:grid_service) }
  it { should belong_to(:volume) }
  it { should belong_to(:host_node) }

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(stack_id: 1) }
  it { should have_index_for(grid_service_id: 1) }
  it { should have_index_for(host_node_id: 1) }
end
