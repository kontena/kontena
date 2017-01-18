require "kontena/cli/helpers/health_helper"

describe Kontena::Cli::Helpers::HealthHelper do
  let :klass do
    Class.new do
      include Kontena::Cli::Helpers::HealthHelper
    end
  end

  subject { klass.new }

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

      describe '#check_grid_health' do
        it "returns error" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 1,
            minimum: 1,
            nodes: grid_nodes['nodes'],
            created: 0,
            connected: 0,
            health: :error,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect(subject).to receive(:show_health).with(:error, "Grid does not have any initial nodes, and requires at least 1 of 1 nodes for operation")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_falsey
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

      describe '#check_grid_health' do
        it "returns error" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 1,
            minimum: 1,
            nodes: grid_nodes['nodes'],
            created: 1,
            connected: 0,
            health: :error,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect(subject).to receive(:show_health).with(:warning, "Grid only has 1 initial nodes, and is not high-availability")
          expect(subject).to receive(:show_health).with(:error, "Initial node node-1 is disconnected")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_falsey
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

      describe '#check_grid_health' do
        it "returns ok" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 1,
            minimum: 1,
            nodes: grid_nodes['nodes'],
            created: 1,
            connected: 1,
            health: :ok,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns true" do
          expect(subject).to receive(:show_health).with(:warning, "Grid only has 1 initial nodes, and is not high-availability")
          expect(subject).to receive(:show_health).with(:ok, "Grid has all 1 of 1 initial nodes connected")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_truthy
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

      describe '#check_grid_health' do
        it "returns error" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 2,
            minimum: 2,
            nodes: grid_nodes['nodes'],
            created: 1,
            connected: 1,
            health: :error,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect(subject).to receive(:show_health).with(:error, "Grid only has 1 of 2 initial nodes required for operation")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_falsey
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

      describe '#check_grid_health' do
        it "returns error" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 2,
            minimum: 2,
            nodes: grid_nodes['nodes'],
            created: 2,
            connected: 2,
            health: :ok,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns true" do
          expect(subject).to receive(:show_health).with(:warning, "Grid only has 2 initial nodes, and is not high-availability")
          expect(subject).to receive(:show_health).with(:ok, "Grid has all 2 of 2 initial nodes connected")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_truthy
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

      describe '#check_grid_health' do
        it "returns error" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 3,
            minimum: 2,
            nodes: grid_nodes['nodes'],
            created: 1,
            connected: 1,
            health: :error,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect(subject).to receive(:show_health).with(:error, "Grid only has 1 of 2 initial nodes required for operation")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_falsey
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

      describe '#check_grid_health' do
        it "returns error" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 3,
            minimum: 2,
            nodes: grid_nodes['nodes'],
            created: 2,
            connected: 1,
            health: :error,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect(subject).to receive(:show_health).with(:warning, "Grid only has 2 of 3 initial nodes required for high-availability")
          expect(subject).to receive(:show_health).with(:error, "Initial node node-2 is disconnected")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_falsey
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

      describe '#check_grid_health' do
        it "returns warning" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 3,
            minimum: 2,
            nodes: grid_nodes['nodes'],
            created: 2,
            connected: 2,
            health: :warning,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect(subject).to receive(:show_health).with(:warning, "Grid only has 2 of 3 initial nodes required for high-availability")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_truthy
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

      describe '#check_grid_health' do
        it "returns warning" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 3,
            minimum: 2,
            nodes: grid_nodes['nodes'],
            created: 3,
            connected: 2,
            health: :warning,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect(subject).to receive(:show_health).with(:warning, "Initial node node-3 is disconnected")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_truthy
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

      describe '#check_grid_health' do
        it "returns warning" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 3,
            minimum: 2,
            nodes: grid_nodes['nodes'][0..1],
            created: 2,
            connected: 2,
            health: :warning,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns false" do
          expect(subject).to receive(:show_health).with(:warning, "Grid only has 2 of 3 initial nodes required for high-availability")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_truthy
        end
      end
    end

    context "with three online nodes" do
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

      describe '#check_grid_health' do
        it "returns warning" do
          expect(subject.check_grid_health(grid, grid_nodes['nodes'])).to eq(
            initial: 3,
            minimum: 2,
            nodes: grid_nodes['nodes'],
            created: 3,
            connected: 3,
            health: :ok,
          )
        end
      end

      describe '#show_grid_health' do
        it "returns true" do
          expect(subject).to receive(:show_health).with(:ok, "Grid has all 3 of 3 initial nodes connected")
          expect(subject.show_grid_health(grid, grid_nodes['nodes']){|sym, msg| }).to be_truthy
        end
      end
    end
  end
end
