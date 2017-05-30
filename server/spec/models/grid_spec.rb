
describe Grid do
  it { should be_timestamped_document }
  it { should be_kind_of(EventStream) }
  it { should have_fields(:name, :token) }
  it { should have_fields(:initial_size).of_type(Integer) }
  it { should have_fields(:stats).of_type(Hash) }
  it { should have_fields(:trusted_subnets, :default_affinity).of_type(Array) }

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
  it { should have_many(:event_logs) }

  it { should embed_one(:grid_logs_opts) }

  it { should have_index_for(token: 1).with_options(unique: true) }

  describe '.after_create' do
    it 'creates default stack automatically' do
      expect {
        grid = described_class.create(name: 'test')
        expect(grid.stacks.count).to eq(1)
      }.to change{ Stack.count }.by(1)
    end
  end

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

  describe '#initial_node' do
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

  describe '#token' do
    let(:grid_with_automatic_token) { Grid.create!(name: 'test1', initial_size: 3) }
    let(:grid_with_manual_token) { Grid.create!(name: 'test2', initial_size: 3, token: 'abcd123456') }
    let(:grid_with_nil_token) { Grid.create!(name: 'test3', initial_size: 3, token: nil) }

    it 'creates a token unless one is supplied' do
      expect(grid_with_automatic_token.token).to match /\A[A-Za-z0-9+\/=]*\Z/
      expect(grid_with_nil_token.token).to match /\A[A-Za-z0-9+\/=]*\Z/
      expect(grid_with_manual_token.token).to eq 'abcd123456'
    end
  end
end
