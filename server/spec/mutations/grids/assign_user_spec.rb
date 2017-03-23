
describe Grids::AssignUser do
  let(:current_user) { User.create!(email: 'jane@domain.com') }
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << current_user
    grid
  }

  describe '#run' do

    it 'validates that current user has permission to assign users' do
      expect(UserAuthorizer).to receive(:assignable_by?).with(current_user, {to: grid}).and_return(false)
      grid.users.delete_all
      outcome = described_class.new(
          current_user: current_user,
          user: user,
          grid: grid
      ).run
      expect(outcome.errors.size).to eq(1)
    end

    it 'assigns a user to grid' do
      allow(UserAuthorizer).to receive(:assignable_by?).with(current_user, {to: grid}).and_return(true)
      expect {
        described_class.new(
            current_user: current_user,
            user: user,
            grid: grid
        ).run
      }.to change{ user.grids.size }.by(1)
    end

    it 'publishes update event for user' do
      allow(UserAuthorizer).to receive(:assignable_by?).with(current_user, {to: grid}).and_return(true)
      expect(user).to receive(:publish_update_event).once
      outcome = described_class.new(
          current_user: current_user,
          user: user,
          grid: grid
      ).run
    end

    it 'returns array of grid users' do
      allow(UserAuthorizer).to receive(:assignable_by?).with(current_user, {to: grid}).and_return(true)
      outcome = described_class.new(
          current_user: current_user,
          user: user,
          grid: grid
      ).run
      expect(outcome.result.is_a?(Array))
      expect(outcome.result.size).to eq(2)
    end

  end
end
