require 'kontena/cli/nodes/env_command'

describe Kontena::Cli::Nodes::EnvCommand do
  include ClientHelpers
  include OutputHelpers

  let :node do
    {
      "id" => nil,
      "token" => 'TPnBKanfXJpi47CCvuv+Gq319AXvXBi0LL/8grXrhPr9MyqcXHsWbUy0Q3stmPGHhjaqubi5ZCwa7LbnSvZ/Iw=='
    }
  end

  before do
    expect(client).to receive(:get).with('nodes/test-grid/node-4/token').and_return(node)
  end

  it 'shows the node env' do
    expect{subject.run(['node-4'])}.to output_lines [
      'KONTENA_URI=ws://someurl.example.com/',
      'KONTENA_NODE_TOKEN=TPnBKanfXJpi47CCvuv+Gq319AXvXBi0LL/8grXrhPr9MyqcXHsWbUy0Q3stmPGHhjaqubi5ZCwa7LbnSvZ/Iw==',
    ]
  end

  it 'shows the --token' do
    expect{subject.run(['--token', 'node-4'])}.to output_lines [
      'TPnBKanfXJpi47CCvuv+Gq319AXvXBi0LL/8grXrhPr9MyqcXHsWbUy0Q3stmPGHhjaqubi5ZCwa7LbnSvZ/Iw==',
    ]
  end
end
