require 'kontena/cli/nodes/label_command'
require 'kontena/cli/nodes/labels/list_command'

describe Kontena::Cli::Nodes::Labels::ListCommand do
  include ClientHelpers
  include OutputHelpers

  before do
    allow(client).to receive(:get).with('nodes/test-grid/node').and_return(node)
  end

  context "for a node without any labels" do
    let :node do
      {
        "id" => 'test-grid/node',
        "name" => "node",
        "labels" => [],
      }
    end

    it "outputs nothing" do
      expect{subject.run(['node'])}.to output_lines [ ]
    end
  end

  context "for a node with labels" do
    let :node do
      {
        "id" => 'test-grid/node',
        "name" => "node",
        "labels" => [
          'test=yes',
        ],
      }
    end

    it "outputs nothing" do
      expect{subject.run(['node'])}.to output_lines [
        'test=yes',
      ]
    end
  end
end
