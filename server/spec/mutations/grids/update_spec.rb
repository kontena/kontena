require_relative '../../spec_helper'

describe Grids::Update do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#run' do
    it 'updates statsd settings' do
      stats = {
        statsd: {
          server: '127.0.0.1',
          port: 8125
        }
      }
      described_class.new(grid: grid, stats: stats).run
      expect(grid.reload.stats['statsd']['server']).to eq('127.0.0.1')
    end

    it 'returns error if grid has errors' do
      outcome = described_class.new(grid: grid, stats: 'foo').run
      expect(outcome.success?).to be_falsey
    end
  end
end
