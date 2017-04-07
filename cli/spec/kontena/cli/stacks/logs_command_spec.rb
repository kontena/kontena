require "kontena/cli/stacks/logs_command"

describe Kontena::Cli::Stacks::LogsCommand do
  include ClientHelpers
  include OutputHelpers

  let (:logs) do
    [
      {
        'id' => '57cff2e8cfee65c8b6efc8bd',
        'name' => 'test-stack.mysql-1',
        'created_at' => '2016-09-07T15:19:04.362690',
        'data' => "mysql log message 1",
      },
    ]
  end
  
  before(:each) do
    Kontena.pastel.resolver.color.disable!
  end

  it "shows stack logs" do
    expect(client).to receive(:get).with('stacks/test-grid/test-stack/container_logs', {
      limit: 100,
    }) { { 'logs' => logs } }

    expect{subject.run(['test-stack'])}.to output_lines [
      "2016-09-07T15:19:04.362690 [test-stack.mysql-1]: mysql log message 1",
    ]
  end

end
