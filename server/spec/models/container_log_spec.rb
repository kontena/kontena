
describe ContainerLog do
  it { should be_timestamped_document }
  it { should have_fields(:type, :data, :name, :instance_number)}

  it { should belong_to(:grid) }
  it { should belong_to(:host_node) }
  it { should belong_to(:grid_service) }
  it { should belong_to(:container) }


  it { should have_index_for(container_id: 1).with_options(background: true) }
  it { should have_index_for(grid_id: 1).with_options(background: true) }
  it { should have_index_for(host_node_id: 1).with_options(background: true) }
  it { should have_index_for(grid_service_id: 1).with_options(background: true) }
  it { should have_index_for(name: 1).with_options(background: true) }
  it { should have_index_for(instance_number: 1).with_options(background: true) }
end
