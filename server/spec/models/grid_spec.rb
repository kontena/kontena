require_relative '../spec_helper'

describe Grid do
  it { should be_timestamped_document }
  it { should have_fields(:name, :token, :overlay_cidr).of_type(String) }
  it { should have_fields(:initial_size).of_type(Integer) }
  it { should have_fields(:stats).of_type(Hash) }
  it { should have_fields(:trusted_subnets).of_type(Array) }

  it { should have_and_belong_to_many(:users) }
  it { should have_many(:host_nodes) }
  it { should have_many(:host_node_stats) }
  it { should have_many(:grid_services) }
  it { should have_many(:grid_secrets) }
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

  describe '#overlay_network_size' do
    it 'should return subnet size from cidr' do
      expect(subject.overlay_network_size).to eq('23')
    end
  end

  describe '#overlay_network_ip' do
    it 'should return overlay network ip' do
      expect(subject.overlay_network_ip).to eq('10.81.0.0')
    end
  end

  describe '#all_overlay_ips' do
    it 'should not include bridge addresses' do
      expect(subject.all_overlay_ips).not_to include('10.81.0.1')
      expect(subject.all_overlay_ips).not_to include('10.81.0.254')
    end

    it 'should include all ips that are not in bridge subnet' do
      expect(subject.all_overlay_ips[0]).to eq('10.81.1.0')
      expect(subject.all_overlay_ips.last).to eq('10.81.1.255')
    end
  end

  describe '#has_initial_nodes?' do
    let(:grid) { Grid.create!(name: 'test', initial_size: 3) }

    it 'returns true if initial nodes are created' do
      HostNode.create(grid: grid, node_id: 'aa', node_number: 1)
      HostNode.create(grid: grid, node_id: 'bb', node_number: 2)
      HostNode.create(grid: grid, node_id: 'cc', node_number: 3)
      expect(grid.has_initial_nodes?).to eq(true)
    end

    it 'returns false if nodes are missing' do
      HostNode.create(grid: grid, node_id: 'aa', node_number: 1)
      HostNode.create(grid: grid, node_id: 'bb', node_number: 2)
      expect(grid.has_initial_nodes?).to eq(false)
    end

    it 'returns false if there are enough nodes but initial node is missing' do
      HostNode.create(grid: grid, node_id: 'aa', node_number: 1)
      HostNode.create(grid: grid, node_id: 'bb', node_number: 2)
      HostNode.create(grid: grid, node_id: 'cc', node_number: 4)
      expect(grid.has_initial_nodes?).to eq(false)
    end
  end

  describe '#initial_node``' do
    let(:grid) { Grid.create!(name: 'test', initial_size: 3) }

    it 'returns true if node is initial member' do
      node = HostNode.create(grid: grid, node_id: 'aa', node_number: 2)
      expect(grid.initial_node?(node)).to be_truthy
    end

    it 'returns false if node is not initial member' do
      node = HostNode.create(grid: grid, node_id: 'aa', node_number: 4)
      expect(grid.initial_node?(node)).to be_falsey
    end
  end
end
