
describe Grids::Delete do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }

  let(:redis_service) {
    GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')
  }

  let(:node) {
    grid.host_nodes.create!(node_id: 'abc', name: 'node-1', node_number: 1)
  }

  describe '#run' do
    context 'when user has not permission to delete grid' do
      it 'returns error' do
        grid # create
        subject = described_class.new(
            user: user,
            grid: grid
        )
        outcome = subject.run
        expect(outcome.errors.size).to eq(1)
      end
    end

    context 'when user has permission to delete grids' do
      before(:each) do
        allow_any_instance_of(GridAuthorizer).to receive(:deletable_by?).with(user).and_return(true)
      end

      it 'deletes a grid' do
        grid # create
        expect {
          outcome = described_class.new(user: user, grid: grid).run
        }.to change{ Grid.count }.by(-1)
      end

      it 'returns error if grid has services' do
        redis_service
        outcome = described_class.new(user: user, grid: grid).run
        expect(outcome.errors.size).to eq(1)
      end

      it 'returns error if grid has nodes' do
        node
        outcome = described_class.new(user: user, grid: grid).run
        expect(outcome.errors.size).to eq(1)
      end
    end
  end
end
