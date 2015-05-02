require_relative '../../spec_helper'

describe Grids::Update do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }


  describe '#run' do
    it 'updates a grid' do
      described_class.new(grid: grid, name: 'updated-grid').run
      expect(grid.reload.name).to eq('updated-grid')
    end

    it 'returns error if grid has errors' do
      outcome = described_class.new(grid: grid, name: 'up').run
      expect(outcome.success?).to be_falsey
    end
  end
end