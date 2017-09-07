describe Grids::Update do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }
  let(:grid_scheduler_job) { instance_double(GridSchedulerJob) }
  let(:grid_scheduler_job_async) { instance_double(GridSchedulerJob) }

  before do
    allow(Celluloid::Actor).to receive(:[]).with(:grid_scheduler_job).and_return(grid_scheduler_job)
    allow(grid_scheduler_job).to receive(:async).and_return(grid_scheduler_job_async)
  end

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

    it 'clears statsd settings' do
      stats = {
        statsd: {
          server: '127.0.0.1',
          port: 8125
        }
      }
      grid.update_attributes stats: stats
      described_class.new(user: user, grid: grid, stats: { statsd: nil }).run
      expect(grid.reload.stats['statsd']).to be_nil
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

    it 'fails to update log settings with multi-line driver' do
      logs = {
        forwarder: "fluentd\nfoobar",
        opts: {
          'fluentd-address': '192.168.0.42:24224'
        }
      }
      expect{
        outcome = described_class.new(user: user, grid: grid, logs: logs).run
        expect(outcome).to_not be_success
      }.to_not change{grid.reload.grid_logs_opts}.from(nil)
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

    describe 'default_affinity' do
      it 'updates the grid default affinity and reschedules services' do
        expect(grid_scheduler_job_async).to receive(:reschedule_grid).with(grid)

        expect{
          outcome = described_class.new(user: user, grid: grid, default_affinity: ['label!=test']).run
          expect(outcome).to be_success
        }.to change{grid.reload.default_affinity}.to(['label!=test'])
      end
    end

    context 'with connected grid nodes' do
      let!(:node) { grid.create_node!('test-node', node_id: 'AAAA', connected: true) }
      let(:rpc_client) { instance_double(RpcClient) }

      before do
        allow(RpcClient).to receive(:new).with(node.node_id, Integer).and_return(rpc_client)
      end

      it 'notifies connected grid nodes' do
        expect(rpc_client).to receive(:notify).with('/agent/node_info', hash_including(

        ))

        described_class.new(user: user, grid: grid).run!
      end
    end
  end
end
