
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
        forwarder: 'fluentd',
        opts: {
          'fluentd-address': '192.168.0.42:24224'
        }
      }
      described_class.new(user: user, grid: grid, logs: logs).run
      grid.reload
      expect(grid.grid_logs_opts.forwarder).to eq('fluentd')
      expect(grid.grid_logs_opts.opts['fluentd-address']).to eq('192.168.0.42:24224')
    end

    it 'removes log settings' do
      logs = {
        forwarder: 'fluentd',
        opts: {
          'fluentd-address': '192.168.0.42:24224'
        }
      }
      grid.grid_logs_opts = GridLogsOpts.new(**logs)
      outcome = described_class.new(user: user, grid: grid, logs: { forwarder: 'none'}).run
      expect(outcome.success?).to be_truthy, outcome.errors
      expect(grid.reload.grid_logs_opts).to be_nil
    end

    it 'fails to update log settings with unsupported driver' do
      logs = {
        forwarder: 'foobar',
        opts: {
          'fluentd-address': '192.168.0.42:24224'
        }
      }
      outcome = described_class.new(user: user, grid: grid, logs: logs).run
      expect(outcome.success?).to be_falsey
      expect(grid.reload.grid_logs_opts).to be_nil
    end

    it 'fails to update fluentd forwarding with no address given' do
      logs = {
        forwarder: 'foobar',
        opts: { }
      }
      outcome = described_class.new(user: user, grid: grid, logs: logs).run
      expect(outcome.success?).to be_falsey
      expect(grid.reload.grid_logs_opts).to be_nil
    end
  end
end
