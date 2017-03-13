require 'kontena/cli/nodes/list_command'

describe Kontena::Cli::Nodes::ListCommand do
  include ClientHelpers
  include OutputHelpers

  before do
    allow(subject).to receive(:health_icon) {|health| health.inspect }
  end

  describe '#show_grid_nodes' do
    context "For a initial_size=3 grid" do
      let :grid do
        {
          "id" => "test",
          "name" => "test",
          "initial_size" => 3,
          "node_count" => 1,
        }
      end

      context "with a single node" do
        let :grid_nodes do
          { "nodes" => [
            {
              "connected" => true,
              "name" => "node-1",
              "node_number" => 1,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
          ] }
        end

        it "outputs node with error" do
          expect{subject.show_grid_nodes(grid, grid_nodes['nodes'])}.to output_table [
            [':error node-1', '1.1-dev', 'online', '1 / 3', '-'],
          ]
        end
      end

      context "with a single online node" do
        let :grid_nodes do
          { "nodes" => [
            {
              "connected" => true,
              "name" => "node-1",
              "node_number" => 1,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
            {
              "connected" => false,
              "name" => "node-2",
              "node_number" => 2,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
          ] }
        end

        it "outputs online node with error" do
          expect{subject.show_grid_nodes(grid, grid_nodes['nodes'])}.to output_table [
            [':error node-1', '1.1-dev', 'online', '1 / 3', '-'],
            [':offline node-2', '1.1-dev', 'offline', '2 / 3', '-'],
          ]
        end
      end

      context "with two online nodes" do
        let :grid_nodes do
          { "nodes" => [
            {
              "connected" => true,
              "name" => "node-1",
              "node_number" => 1,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
            {
              "connected" => true,
              "name" => "node-2",
              "node_number" => 2,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
          ] }
        end

        it "outputs both nodes with warning" do
          expect{subject.show_grid_nodes(grid, grid_nodes['nodes'])}.to output_table [
            [':warning node-1', '1.1-dev', 'online', '1 / 3', '-'],
            [':warning node-2', '1.1-dev', 'online', '2 / 3', '-'],
          ]
        end
      end

      context "with two online nodes and one offline node" do
        let :grid_nodes do
          { "nodes" => [
            {
              "connected" => true,
              "name" => "node-1",
              "node_number" => 1,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
            {
              "connected" => true,
              "name" => "node-2",
              "node_number" => 2,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
            {
              "connected" => false,
              "name" => "node-3",
              "node_number" => 3,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
          ] }
        end

        it "outputs two nodes with warning and one offline" do
          expect{subject.show_grid_nodes(grid, grid_nodes['nodes'])}.to output_table [
            [':warning node-1', '1.1-dev', 'online',  '1 / 3', '-'],
            [':warning node-2', '1.1-dev', 'online',  '2 / 3', '-'],
            [':offline node-3', '1.1-dev', 'offline', '3 / 3', '-'],
          ]
        end
      end

      context "with two online initial nodes and one non-initial node" do
        let :grid_nodes do
          { "nodes" => [
            {
              "connected" => true,
              "name" => "node-1",
              "node_number" => 1,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
            {
              "connected" => true,
              "name" => "node-2",
              "node_number" => 2,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
            {
              "connected" => true,
              "name" => "node-4",
              "node_number" => 4,
              "initial_member" => false,
              'agent_version' => '1.1-dev',
            },
          ] }
        end

        it "outputs two nodes with warning and one online" do
          expect{subject.show_grid_nodes(grid, grid_nodes['nodes'])}.to output_table [
            [':warning node-1', '1.1-dev', 'online',  '1 / 3', '-'],
            [':warning node-2', '1.1-dev', 'online',  '2 / 3', '-'],
            [':ok node-4', '1.1-dev', 'online', '-', '-'],
          ]
        end
      end

      context "with three online initial nodes" do
        let :grid_nodes do
          { "nodes" => [
            {
              "connected" => true,
              "name" => "node-1",
              "node_number" => 1,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
            {
              "connected" => true,
              "name" => "node-2",
              "node_number" => 2,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
            {
              "connected" => true,
              "name" => "node-3",
              "node_number" => 3,
              "initial_member" => true,
              'agent_version' => '1.1-dev',
            },
          ] }
        end

        it "outputs three nodes with ok" do
          expect{subject.show_grid_nodes(grid, grid_nodes['nodes'])}.to output_table [
            [':ok node-1', '1.1-dev', 'online', '1 / 3', '-'],
            [':ok node-2', '1.1-dev', 'online', '2 / 3', '-'],
            [':ok node-3', '1.1-dev', 'online', '3 / 3', '-'],
          ]
        end
      end
    end
  end
end
