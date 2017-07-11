require 'kontena/cli/nodes/label_command'
require 'kontena/cli/nodes/labels/remove_command'

describe Kontena::Cli::Nodes::Labels::RemoveCommand do
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

    it "doesn't remove anything" do
      expect(client).to receive(:put).with('nodes/test-grid/node', {
          labels: [],
      })
      subject.run(['node', 'test=yes'])
    end
  end

  context "for a node with labels" do
    let :node do
      {
        "id" => 'test-grid/node',
        "name" => "node",
        "labels" => [
          'test=yes',
          'test=no',
        ],
      }
    end

    it "removes labels" do
      expect(client).to receive(:put).with('nodes/test-grid/node', {
          labels: ['test=no'],
      })

      subject.run(['node', 'test=yes'])
    end

    it "removes all labels" do
      expect(client).to receive(:put).with('nodes/test-grid/node', {
          labels: [],
      })

      subject.run(['node', 'test=yes', 'test=no'])
    end
  end
end
