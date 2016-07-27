require_relative '../spec_helper'

describe Stack do

  let(:grid) do
    Grid.create(name: 'test-grid')
  end

  let(:grid_service) do
    GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8')
  end

  it { should be_timestamped_document }
  it { should have_fields(:name, :version).of_type(String) }
  it { should belong_to(:grid) }
  it { should have_many(:stack_revisions)}
  it { should have_many(:grid_services)}

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(name: 1) }
end
