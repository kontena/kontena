require 'kontena/cli/nodes/health_command'

describe Kontena::Cli::Nodes::HealthCommand do
  include ClientHelpers
  include OutputHelpers

  before do
    allow(subject).to receive(:health_icon) {|health| health.inspect }
  end

  context "for an online node" do
    let :node do
      {
        "connected" => true,
        "name" => "node-4",
        "node_number" => 4,
        "initial_member" => false,
      }
    end

    let :grid_health do
      :ok
    end

    describe '#node_health' do
      it "returns ok" do
        expect(subject.node_health(node, grid_health)).to eq(:ok)
      end
    end

    describe '#show_node_health' do
      it "returns true" do
        expect{subject.show_node_health(node)}.to return_and_output true,
          ":ok Node is online"
      end
    end
  end

  context "for an offline node" do
    let :node do
      {
        "connected" => false,
        "name" => "node-4",
        "node_number" => 4,
        "initial_member" => false,
      }
    end

    let :grid_health do
      :ok
    end

    describe '#node_health' do
      it "returns offline" do
        expect(subject.node_health(node, grid_health)).to eq(:offline)
      end
    end

    describe '#show_node_health' do
      it "returns false" do
        expect{subject.show_node_health(node)}.to return_and_output false,
          ":offline Node is offline"
      end
    end
  end

  context "for an online initial node in an ok grid" do
    let :node do
      {
        "connected" => true,
        "name" => "node-1",
        "node_number" => 1,
        "initial_member" => true,
      }
    end

    let :grid_health do
      :ok
    end

    describe '#node_health' do
      it "returns ok" do
        expect(subject.node_health(node, grid_health)).to eq(:ok)
      end
    end

    describe '#show_node_health' do
      it "returns true" do
        expect{subject.show_node_health(node)}.to return_and_output true,
          ":ok Node is online"
      end
    end
  end

  context "for an online initial node in a warning grid" do
    let :node do
      {
        "connected" => true,
        "name" => "node-1",
        "node_number" => 1,
        "initial_member" => true,
      }
    end

    let :grid_health do
      :warning
    end

    describe '#node_health' do
      it "returns ok" do
        expect(subject.node_health(node, grid_health)).to eq(:warning)
      end
    end

    describe '#show_node_health' do
      it "returns true" do
        expect{subject.show_node_health(node)}.to return_and_output true,
          ":ok Node is online"
      end
    end
  end

  context "for an online initial node in an error grid" do
    let :node do
      {
        "connected" => true,
        "name" => "node-1",
        "node_number" => 1,
        "initial_member" => true,
      }
    end

    let :grid_health do
      :error
    end

    describe '#node_health' do
      it "returns ok" do
        expect(subject.node_health(node, grid_health)).to eq(:error)
      end
    end

    describe '#show_node_health' do
      it "returns true" do
        expect{subject.show_node_health(node)}.to return_and_output true,
          ":ok Node is online"
      end
    end
  end

  context "for an offline initial node in a warning grid" do
    let :node do
      {
        "connected" => false,
        "name" => "node-1",
        "node_number" => 1,
        "initial_member" => true,
      }
    end

    let :grid_health do
      :warning
    end

    describe '#node_health' do
      it "returns offline" do
        expect(subject.node_health(node, grid_health)).to eq(:offline)
      end
    end

    describe '#show_node_health' do
      it "returns false" do
        expect{subject.show_node_health(node)}.to return_and_output false,
          ":offline Node is offline"
      end
    end
  end

  context "for an offline initial node in a error grid" do
    let :node do
      {
        "connected" => false,
        "name" => "node-1",
        "node_number" => 1,
        "initial_member" => true,
      }
    end

    let :grid_health do
      :error
    end

    describe '#node_health' do
      it "returns offline" do
        expect(subject.node_health(node, grid_health)).to eq(:offline)
      end
    end

    describe '#show_node_health' do
      it "returns false" do
        expect{subject.show_node_health(node)}.to return_and_output false,
          ":offline Node is offline"
      end
    end
  end
end
