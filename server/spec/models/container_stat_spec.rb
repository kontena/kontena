
describe ContainerStat do
  it { should be_timestamped_document }
  it { should have_fields(:spec, :cpu, :memory, :filesystem, :diskio, :network)}

  it { should belong_to(:grid) }
  it { should belong_to(:grid_service) }
  it { should belong_to(:container) }


  it { should have_index_for(container_id: 1) }
  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_service_id: 1) }
  it { should have_index_for(created_at: 1) }

end
