require_relative '../spec_helper'

describe Grid do
  it { should be_timestamped_document }
  it { should have_fields(:name, :token, :discovery_url, :initial_size)}

  it { should have_and_belong_to_many(:users) }
  it { should have_many(:host_nodes) }
  it { should have_many(:grid_services) }
  it { should have_many(:containers) }
  it { should have_many(:container_logs) }
  it { should have_many(:container_stats) }
  it { should have_many(:audit_logs) }
  it { should have_many(:registries) }

  it { should have_index_for(token: 1).with_options(unique: true) }

  describe '#free_node_numbers' do
    it 'returns 1-254 if there are no nodes yet' do
      expect(subject.free_node_numbers).to eq((1..254).to_a)
    end

    it 'returns only available numbers' do
      grid = Grid.create!(name: 'test')
      HostNode.create(grid: grid, node_id: 'aa', node_number: 1)
      HostNode.create(grid: grid, node_id: 'bb', node_number: 5)
      available = (1..254).to_a - [1, 5]
      expect(grid.free_node_numbers).to eq(available)
    end
  end
end
