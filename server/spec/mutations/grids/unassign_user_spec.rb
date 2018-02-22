
describe Grids::UnassignUser do
  let(:current_user) { User.create!(email: 'jane@domain.com') }
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:user2) { User.create!(email: 'joe2@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << current_user
    grid.users << user
    grid
  }

  it 'validates that current user has permission to unassign users' do
    expect(UserAuthorizer).to receive(:assignable_by?).with(current_user, {to: grid}).and_return(false)
    outcome = described_class.new(
        current_user: current_user,
        user: user2,
        grid: grid
    ).run
    expect(outcome).to_not be_success
    expect(outcome.errors.message).to eq 'grid' => "Operation not allowed"
  end

  context 'for an authorized user' do
    before do
      allow(UserAuthorizer).to receive(:assignable_by?).with(current_user, {to: grid}).and_return(true)
    end

    it 'unassigns a user from grid' do
      expect {
        outcome = described_class.new(
          current_user: current_user,
          user: user,
          grid: grid
        ).run
        expect(outcome).to be_success
      }.to change{ user.grids.size }.by(-1)
    end

    it 'returns array of grid users' do
      outcome = described_class.new(
          current_user: current_user,
          user: user,
          grid: grid
      ).run
      expect(outcome).to be_success
      expect(outcome.result).to eq [current_user]
    end

    it 'publishes update event for user' do
      expect(grid).to receive(:publish_update_event).once
      outcome = described_class.new(
        current_user: current_user,
        user: user,
        grid: grid
      ).run
      expect(outcome).to be_success
    end

    context 'with only a single user in the grid' do
      before do
        grid.users = [current_user]
        grid.save!
      end

      it 'returns error if removing the only grid user' do
        expect {
          outcome = described_class.new(
              current_user: current_user,
              user: current_user,
              grid: grid
          ).run
          expect(outcome).to_not be_success
          expect(outcome.errors.message).to eq 'grid' => "Cannot remove last user"
        }.to_not change{ user.grids.size }
      end
    end
  end
end
