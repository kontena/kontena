require 'kontena/cli/nodes/health_command'

describe Kontena::Cli::Nodes::HealthCommand do
  include ClientHelpers
  include OutputHelpers

  before do
    allow(subject).to receive(:health_icon) {|health| health.inspect }
  end

  before do
    allow(client).to receive(:get).with('nodes/test-grid/node').and_return(node)
  end

  context "for an online node" do
    let :node do
      {
        "name" => "node",
        "node_number" => 4,
        "initial_member" => false,
        "connected" => true,
      }
    end

    it "outputs ok" do
      expect{subject.run(['node'])}.to output_lines [
        ":ok Node is online",
      ]
    end
  end

  context "for an offline node" do
    let :node do
      {
        "name" => "node",
        "node_number" => 4,
        "initial_member" => false,
        "connected" => false,
      }
    end

    it "fails as error" do
      expect{subject.run(['node'])}.to exit_with_error.and output_lines [
        ":offline Node is offline",
      ]
    end
  end
end
