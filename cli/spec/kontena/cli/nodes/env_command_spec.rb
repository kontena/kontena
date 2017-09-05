require 'kontena/cli/nodes/env_command'

describe Kontena::Cli::Nodes::EnvCommand do
  include ClientHelpers
  include OutputHelpers

  context 'for a node created with a token' do
    let :node_token do
      {
        "id" => 'test-grid/node-4',
        "token" => 'TPnBKanfXJpi47CCvuv+Gq319AXvXBi0LL/8grXrhPr9MyqcXHsWbUy0Q3stmPGHhjaqubi5ZCwa7LbnSvZ/Iw=='
      }
    end

    before do
      expect(client).to receive(:get).with('nodes/test-grid/node-4/token').and_return(node_token)
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

  context 'for a node without any token' do
    before do
      expect(client).to receive(:get).with('nodes/test-grid/node-1/token').and_raise(Kontena::Errors::StandardError.new(404, "Host node does not have a node token"))
    end

    it 'uses the grid token' do
      expect{subject.run(['node-1'])}.to exit_with_error.and output(" [error] Node node-1 was not created with a node token. Use `kontena grid env` instead\n").to_stderr
    end
  end
end
