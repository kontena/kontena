require 'kontena/cli/grid_options'
require "kontena/cli/containers/logs_command"

describe Kontena::Cli::Containers::LogsCommand do
  include ClientHelpers

  context "for a single container with logs" do
    let(:logs) do
      [
        {
          'id' => '57cff2e8cfee65c8b6efc8bd',
          'name' => 'test-mysql-1',
          'created_at' => '2016-09-07T15:19:04.362690',
          'data' => "mysql log message 1",
        },
        {
          'id' => '57cff2e8cfee65c8b6efc8be',
          'name' => 'test-mysql-1',
          'created_at' => '2016-09-07T15:19:04.500000',
          'data' => "mysql log message 2",
        },
        {
          'id' => '57cff2e8cfee65c8b6efc8c1',
          'name' => 'test-mysql-1',
          'created_at' => '2016-09-07T15:19:06.100000',
          'data' => "mysql log message 3",
        },
      ]
    end

    before(:each) do
      Kontena.pastel.resolver.color.disable!
    end

    it "shows all logs" do
      allow(client).to receive(:get).with('containers/test-grid/node-1/test-mysql-1/logs', {
        limit: 100,
      }) { { 'logs' => logs } }

      expect { subject.run(['node-1/test-mysql-1']) }.to output(<<LOGS
2016-09-07T15:19:04.362690 test-mysql-1: mysql log message 1
2016-09-07T15:19:04.500000 test-mysql-1: mysql log message 2
2016-09-07T15:19:06.100000 test-mysql-1: mysql log message 3
LOGS
      ).to_stdout
    end

    it "errors for an invalid --lines" do
      expect { subject.run(["--lines=invalid", "node-1/test-mysql-1"]) }.to raise_error(Clamp::UsageError, "option '--lines': invalid value for Integer(): \"invalid\"")
    end
  end
end
