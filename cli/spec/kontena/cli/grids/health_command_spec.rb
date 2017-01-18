require 'kontena/cli/grids/health_command'

describe Kontena::Cli::Grids::HealthCommand do
  include ClientHelpers
  include OutputHelpers

  before do
    allow(subject).to receive(:health_icon) {|health| health.inspect }
  end

  context "For a initial_size=1 grid" do
    let :grid do
      {
        "id" => "test",
        "name" => "test",
        "initial_size" => 1,
        "node_count" => 1,
      }
    end

    context "without any nodes" do
      let :grid_nodes do
        { "nodes" => [ ] }
      end

      describe '#grid_health' do
        it "returns error" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:error)
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output false, <<~OUT
              :error Grid does not have any initial nodes, and requires at least 1 of 1 nodes for operation
              :error Grid only has 0 of 1 initial nodes online, and is not operational
          OUT
        end
      end
    end

    context "with a single offline node" do
      let :grid_nodes do
        { "nodes" => [
          {
            "connected" => false,
            "name" => "node-1",
            "node_number" => 1,
            "initial_member" => true,
          },
        ] }
      end

      describe '#grid_health' do
        it "returns error" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:error)
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output false, <<~OUT
            :warning Grid only has 1 initial nodes, and is not high-availability
            :error Grid only has 0 of 1 initial nodes online, and is not operational
            :error Initial node node-1 is offline
          OUT
        end
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
          },
        ] }
      end

      describe '#grid_health' do
        it "returns ok" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:ok)
        end
      end

      describe '#show_grid_health' do
        it "returns true" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output true, <<~OUT
            :warning Grid only has 1 initial nodes, and is not high-availability
            :ok Grid has all 1 of 1 initial nodes connected
          OUT
        end
      end
    end
  end

  context "For a initial_size=2 grid" do
    let :grid do
      {
        "id" => "test",
        "name" => "test",
        "initial_size" => 2,
        "node_count" => 1,
      }
    end

    context "with a single online node" do
      let :grid_nodes do
        { "nodes" => [
          {
            "connected" => true,
            "name" => "node-1",
            "node_number" => 1,
            "initial_member" => true,
          },
        ] }
      end

      describe '#grid_health' do
        it "returns error" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:error)
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output false, <<~OUT
            :error Grid only has 1 of 2 initial nodes required for operation
          OUT
        end
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
          },
          {
            "connected" => true,
            "name" => "node-2",
            "node_number" => 2,
            "initial_member" => true,
          },
        ] }
      end

      describe '#grid_health' do
        it "returns ok" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:ok)
        end
      end

      describe '#show_grid_health' do
        it "returns true" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output true, <<~OUT
            :warning Grid only has 2 initial nodes, and is not high-availability
            :ok Grid has all 2 of 2 initial nodes connected
          OUT
        end
      end
    end
  end

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
          },
        ] }
      end

      describe '#grid_health' do
        it "returns error" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:error)
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output false, <<~END
            :error Grid only has 1 of 2 initial nodes required for operation
          END
        end
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
          },
          {
            "connected" => false,
            "name" => "node-2",
            "node_number" => 1,
            "initial_member" => true,
          },
        ] }
      end

      describe '#grid_health' do
        it "returns error" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:error)
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output false, <<~END
            :warning Grid only has 2 of 3 initial nodes required for high-availability
            :error Initial node node-2 is disconnected
          END
        end
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
          },
          {
            "connected" => true,
            "name" => "node-2",
            "node_number" => 2,
            "initial_member" => true,
          },
        ] }
      end

      describe '#grid_health' do
        it "returns warning" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:warning)
        end
      end

      describe '#show_grid_health' do
        it "returns true" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output true, <<~END
            :warning Grid only has 2 of 3 initial nodes required for high-availability
          END
        end
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
          },
          {
            "connected" => true,
            "name" => "node-2",
            "node_number" => 2,
            "initial_member" => true,
          },
          {
            "connected" => false,
            "name" => "node-3",
            "node_number" => 3,
            "initial_member" => true,
          },
        ] }
      end

      describe '#grid_health' do
        it "returns warning" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:warning)
        end
      end

      describe '#show_grid_health' do
        it "returns true" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output true, <<~END
            :warning Initial node node-3 is disconnected
          END
        end
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
          },
          {
            "connected" => true,
            "name" => "node-2",
            "node_number" => 2,
            "initial_member" => true,
          },
          {
            "connected" => true,
            "name" => "node-4",
            "node_number" => 4,
            "initial_member" => false,
          },
        ] }
      end

      describe '#grid_health' do
        it "returns warning" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:warning)
        end
      end

      describe '#show_grid_health' do
        it "returns true" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output true, <<~END
            :warning Grid only has 2 of 3 initial nodes required for high-availability
          END
        end
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
          },
          {
            "connected" => true,
            "name" => "node-2",
            "node_number" => 2,
            "initial_member" => true,
          },
          {
            "connected" => true,
            "name" => "node-3",
            "node_number" => 3,
            "initial_member" => true,
          },
        ] }
      end

      describe '#grid_health' do
        it "returns ok" do
          expect(subject.grid_health(grid, grid_nodes['nodes'])).to eq(:ok)
        end
      end

      describe '#show_grid_health' do
        it "returns true" do
          expect{subject.show_grid_health(grid, grid_nodes['nodes'])}.to return_and_output true, <<~END
            :ok Grid has all 3 of 3 initial nodes connected
          END
        end
      end
    end
  end
end
