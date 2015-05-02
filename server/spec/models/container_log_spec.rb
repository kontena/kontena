require_relative '../spec_helper'

describe ContainerLog do
  it { should be_timestamped_document }
  it { should have_fields(:type, :data, :name)}

  it { should belong_to(:grid) }
  it { should belong_to(:grid_service) }
  it { should belong_to(:container) }


  it { should have_index_for(container_id: 1) }
  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_service_id: 1) }
  it { should have_index_for(name: 1) }
  it { should have_index_for(data: 'text') }
end
