require_relative '../../spec_helper'

describe Grids::AssignUser do
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

    it 'assigns a user to grid' do
      user
      expect {
        described_class.new(
            current_user: current_user,
            user: user,
            grid: grid
        ).run
      }.to change{ user.grids.size }.by(1)
    end

    it 'returns array of grid users' do
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
