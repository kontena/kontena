
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

  let(:initial_size) { 3 }
  subject { Grid.create!(name: 'test', initial_size: initial_size) }

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
      HostNode.create!(grid: grid, node_id: 'aa', name: 'node-1', node_number: 1)
      HostNode.create!(grid: grid, node_id: 'bb', name: 'node-2', node_number: 5)
      available = (1..254).to_a - [1, 5]
      expect(grid.free_node_numbers).to eq(available)
    end
  end

  describe '#create_node!' do
    it 'creates and returns node with assigned node_number' do
      node = subject.create_node!('test-node')

      expect(node).to be_a HostNode
      expect(node.name).to eq 'test-node'
      expect(node.node_number).to eq 1
    end

    context 'with an existing node' do
      let(:other_node) { subject.create_node!('test-node') }

      before do
        other_node
      end

      it 'fails with a duplicate name' do
        expect{subject.create_node!('test-node')}.to raise_error(Mongo::Error::OperationFailure, /E11000 duplicate key error/)
      end

      it 'retries on node_number race condition' do
        expect(subject).to receive(:reserved_node_numbers).once.and_return([])
        expect(subject).to receive(:reserved_node_numbers).once.and_call_original

        node = subject.create_node!('test-node2')
        expect(node.name).to eq 'test-node2'
        expect(node.node_number).to eq 2
      end

      describe 'with (ensure_unique_name: true)' do
        it 'renames on name conflict' do
          node = subject.create_node!('test-node', ensure_unique_name: true)

          expect(node).to be_a HostNode
          expect(node.name).to eq 'test-node-2'
          expect(node.node_number).to eq 2
        end

        it 'retries with a different node_number after name conflict' do
          expect(subject).to receive(:warn).with(/rename node test-node on name conflict/) do
            HostNode.create!(grid: subject, name: 'other-node', node_number: 2)
          end

          node = subject.create_node!('test-node', ensure_unique_name: true)

          expect(node.name).to eq 'test-node-3'
          expect(node.node_number).to eq 3
        end
      end
    end
  end

  describe '#has_initial_nodes?' do
    let(:grid) { Grid.create!(name: 'test', initial_size: 3) }

    it 'returns true if initial nodes are created' do
      HostNode.create!(grid: grid, node_id: 'aa', name: 'node-1', node_number: 1)
      HostNode.create!(grid: grid, node_id: 'bb', name: 'node-2', node_number: 2)
      HostNode.create!(grid: grid, node_id: 'cc', name: 'node-3', node_number: 3)
      expect(grid.has_initial_nodes?).to eq(true)
    end

    it 'returns false if nodes are missing' do
      HostNode.create!(grid: grid, node_id: 'aa', name: 'node-1', node_number: 1)
      HostNode.create!(grid: grid, node_id: 'bb', name: 'node-2', node_number: 2)
      expect(grid.has_initial_nodes?).to eq(false)
    end

    it 'returns false if there are enough nodes but initial node is missing' do
      HostNode.create!(grid: grid, node_id: 'aa', name: 'node-1', node_number: 1)
      HostNode.create!(grid: grid, node_id: 'bb', name: 'node-2', node_number: 2)
      HostNode.create!(grid: grid, node_id: 'cc', name: 'node-4', node_number: 4)
      expect(grid.has_initial_nodes?).to eq(false)
    end
  end

  describe '#initial_node' do
    let(:grid) { Grid.create!(name: 'test', initial_size: 3) }

    it 'returns true if node is initial member' do
      node = HostNode.create!(grid: grid, node_id: 'aa', name: 'node-2', node_number: 2)
      expect(grid.initial_node?(node)).to be_truthy
    end

    it 'returns false if node is not initial member' do
      node = HostNode.create!(grid: grid, node_id: 'aa', name: 'node-4',  node_number: 4)
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
