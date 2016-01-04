require_relative '../../spec_helper'

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
    grid.host_nodes.create!(node_id: 'abc')
  }

  describe '#run' do
    it 'deletes a grid' do
      grid
      expect {
        described_class.new(grid: grid).run
      }.to change{ Grid.count }.by(-1)
    end

    it 'returns error if grid has services' do
      redis_service
      outcome = described_class.new(grid: grid).run
      expect(outcome.errors.size).to eq(1)
    end

    it 'returns error if grid has nodes' do
      node
      outcome = described_class.new(grid: grid).run
      expect(outcome.errors.size).to eq(1)
    end
  end
end