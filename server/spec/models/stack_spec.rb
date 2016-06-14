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
  it { should have_many(:grid_services)}
  #it { should have_many(:audit_logs)}

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(name: 1) }

  it 'should set default state to initialized' do
  	stack = Stack.create(grid: grid, name: 'my stack')
  	expect(stack.state).to eq(:initialized)
  	expect(stack.initialized?).to be_truthy
  end
end
