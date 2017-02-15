
describe Grids::Update, celluloid: true do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }

  describe '#run' do
    before(:each) do
      allow_any_instance_of(GridAuthorizer).to receive(:updatable_by?).with(user).and_return(true)
    end

    it 'updates statsd settings' do
      stats = {
        statsd: {
          server: '127.0.0.1',
          port: 8125
        }
      }
      described_class.new(user: user, grid: grid, stats: stats).run
      expect(grid.reload.stats['statsd']['server']).to eq('127.0.0.1')
    end

    it 'returns error if grid has errors' do
      outcome = described_class.new(user: user, grid: grid, stats: 'foo').run
      expect(outcome.success?).to be_falsey
    end

    it 'updates log settings' do
      logs = {
        driver: 'fluentd',
        opts: {
          fluentd_address: '192.168.0.42:24224'
        }
      }
      described_class.new(user: user, grid: grid, logs: logs).run
      expect(grid.reload.logs['driver']).to eq('fluentd')
      expect(grid.reload.logs['opts']['fluentd_address']).to eq('192.168.0.42:24224')
    end

    it 'removes log settings' do
      logs = {
        driver: 'fluentd',
        opts: {
          fluentd_address: '192.168.0.42:24224'
        }
      }
      grid.update_attributes({:logs => logs})
      outcome = described_class.new(user: user, grid: grid, logs: { driver: 'none'}).run
      expect(outcome.success?).to be_truthy, outcome.errors
      expect(grid.reload.logs).to eq({})
    end

    it 'fails update log settings with unsupported driver' do
      logs = {
        driver: 'foobar',
        opts: {
          fluentd_address: '192.168.0.42:24224'
        }
      }
      outcome = described_class.new(user: user, grid: grid, logs: logs).run
      expect(outcome.success?).to be_falsey
      expect(grid.reload.logs).to eq({})
    end
  end
end
