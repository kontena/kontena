
describe Grids::AssignUser do
  let(:current_user) { User.create!(email: 'jane@domain.com') }
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << current_user
    grid
  }

  it 'validates that current user has permission to assign users' do
    expect(UserAuthorizer).to receive(:assignable_by?).with(current_user, {to: grid}).and_return(false)
    grid.users.delete_all
    outcome = described_class.new(
        current_user: current_user,
        user: user,
        grid: grid
    ).run
    expect(outcome).to_not be_success
    expect(outcome.errors.message).to eq 'grid' => "Operation not allowed"
  end

  context 'for an authorized user' do
    before do
      allow(UserAuthorizer).to receive(:assignable_by?).with(current_user, {to: grid}).and_return(true)
    end

    it 'assigns a user to grid' do
      expect {
        outcome = described_class.new(
            current_user: current_user,
            user: user,
            grid: grid
        ).run
        expect(outcome).to be_success
      }.to change{ user.grids.size }.by(1)
    end

    it 'publishes update event for user' do
      expect(user).to receive(:publish_update_event).once
      outcome = described_class.new(
          current_user: current_user,
          user: user,
          grid: grid
      ).run
      expect(outcome).to be_success
    end

    it 'returns array of grid users' do
      outcome = described_class.new(
          current_user: current_user,
          user: user,
          grid: grid
      ).run
      expect(outcome).to be_success
      expect(outcome.result).to match_array [current_user, user]
    end

  end
end
