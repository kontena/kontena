
describe Grids::UnassignUser do
  let(:current_user) { User.create!(email: 'jane@domain.com') }
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << current_user
    grid
  }

  describe '#run' do

    it 'validates that current user belongs to grid' do
      grid.users.delete_all
      outcome = described_class.new(
          current_user: current_user,
          user: user,
          grid: grid
      ).run
      expect(outcome.errors.size).to eq(1)
    end

    it 'unassigns a user from grid' do
      grid.users << user
      expect {
        described_class.new(
            current_user: current_user,
            user: user,
            grid: grid
        ).run
      }.to change{ user.grids.size }.by(-1)
    end

    it 'publishes update event for user' do
      grid.users << user
      expect(grid).to receive(:publish_update_event).once      
      outcome = described_class.new(
          current_user: current_user,
          user: user,
          grid: grid
      ).run
    end

    context 'when a grid has only one user'
    it 'returns error' do
      expect {
        outcome = described_class.new(
            current_user: current_user,
            user: current_user,
            grid: grid
        ).run
        expect(outcome.success?).to be_falsey
      }.to change{ user.grids.size }.by(0)

    end

    it 'returns array of grid users' do
      grid.users << user
      outcome = described_class.new(
          current_user: current_user,
          user: user,
          grid: grid
      ).run
      expect(outcome.result.is_a?(Array))
      expect(outcome.result.size).to eq(1)
    end

  end
end
