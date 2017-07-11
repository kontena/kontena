require 'kontena/cli/nodes/label_command'
require 'kontena/cli/nodes/labels/add_command'

describe Kontena::Cli::Nodes::Labels::AddCommand do
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

    it "adds the labels" do
      expect(client).to receive(:put).with('nodes/test-grid/node', {
          labels: ['test=yes'],
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
        ],
      }
    end

    it "adds new labels" do
      expect(client).to receive(:put).with('nodes/test-grid/node', {
          labels: ['test=yes', 'test=no'],
      })

      subject.run(['node', 'test=no'])
    end

    it "deduplicates labels" do
      expect(client).to receive(:put).with('nodes/test-grid/node', {
          labels: ['test=yes'],
      })

      subject.run(['node', 'test=yes'])
    end
  end
end
