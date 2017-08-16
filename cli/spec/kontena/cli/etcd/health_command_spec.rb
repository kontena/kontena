require 'kontena/cli/etcd/health_command'

describe Kontena::Cli::Etcd::HealthCommand do
  include ClientHelpers
  include OutputHelpers

  before do
    allow(subject).to receive(:health_icon) {|health| health.inspect }
  end

  let :node1_errors do
    {
      'connection' => "Websocket disconnected at 2017-08-16 14:50:46 UTC with code 1006: ",
    }
  end
  let :node2_errors do
    {
      'etcd_health' => "RPC timeout",
    }
  end
  let :node3_health do
    {
      "id" => 'test-grid/node-3',
      "name" => "node-3",
      "connected" => true,
      'etcd_health' => {
        'health' => false,
        'error' => nil,
      },
    }
  end
  let :node4_health do
    {
      "id" => 'test-grid/node-4',
      "name" => "node-4",
      "connected" => true,
      'etcd_health' => {
        'health' => nil,
        'error' => "proxy: zero endpoints currently available",
      },
    }
  end
  let :node5_health do
    {
      "id" => 'test-grid/node-5',
      "name" => "node-5",
      "connected" => true,
      'etcd_health' => {
        'health' => true,
        'error' => nil,
      },
    }
  end

  before do
    allow(client).to receive(:get).with('nodes/test-grid/node-1/health').and_raise(Kontena::Errors::StandardErrorHash.new(422, "", node1_errors))
    allow(client).to receive(:get).with('nodes/test-grid/node-2/health').and_raise(Kontena::Errors::StandardErrorHash.new(422, "", node2_errors))
    allow(client).to receive(:get).with('nodes/test-grid/node-3/health').and_return(node3_health)
    allow(client).to receive(:get).with('nodes/test-grid/node-4/health').and_return(node4_health)
    allow(client).to receive(:get).with('nodes/test-grid/node-5/health').and_return(node5_health)
  end

  context "For an offline node-1" do
    it "shows offline and returns false" do
      expect{subject.run(['node-1'])}.to exit_with_error.and output_lines [
        ":offline Node test-grid/node-1 connection error: Websocket disconnected at 2017-08-16 14:50:46 UTC with code 1006: ",
      ]
    end
  end

  context "For a node-2 with RPC errors" do
    it "shows errored and returns false" do
      expect{subject.run(['node-2'])}.to exit_with_error.and output_lines [
        ":offline Node test-grid/node-2 etcd_health error: RPC timeout",
      ]
    end
  end

  context "For a node-3 that returns health=false" do
    it "shows unhealthy and returns false" do
      expect{subject.run(['node-3'])}.to exit_with_error.and output_lines [
        ":error Node node-3 etcd is unhealthy",
      ]
    end
  end

  context "For an unhealthy node-4" do
    it "shows unhealthy and returns false" do
      expect{subject.run(['node-4'])}.to exit_with_error.and output_lines [
        ":error Node node-4 etcd is unhealthy: proxy: zero endpoints currently available",
      ]
    end
  end

  context "For a healthy node-5" do
    it "shows healthy and returns true" do
      expect{subject.run(['node-5'])}.to output_lines [
        ":ok Node node-5 etcd is healthy",
      ]
    end
  end

  context "For a grid of mixed nodes" do
    let :grid_nodes do
      [
        {
          'id' => 'test-grid/node-1',
        },
        {
          'id' => 'test-grid/node-2',
        },
        {
          'id' => 'test-grid/node-3',
        },
        {
          'id' => 'test-grid/node-4',
        },
        {
          'id' => 'test-grid/node-5',
        },
      ]
    end

    before do
      allow(client).to receive(:get).with('grids/test-grid/nodes').and_return(
        'nodes' => grid_nodes,
      )
    end

    it 'shows all nodes and exits with an error' do
      expect{subject.run([])}.to exit_with_error.and output_lines [
        ":offline Node test-grid/node-1 connection error: Websocket disconnected at 2017-08-16 14:50:46 UTC with code 1006: ",
        ":offline Node test-grid/node-2 etcd_health error: RPC timeout",
        ":error Node node-3 etcd is unhealthy",
        ":error Node node-4 etcd is unhealthy: proxy: zero endpoints currently available",
        ":ok Node node-5 etcd is healthy",
      ]
    end
  end

  context 'for a grid with healthy nodes' do
    let :grid_nodes do
      [
        {
          'id' => 'test-grid/node-5',
        },
        {
          'id' => 'test-grid/node-5',
        },
      ]
    end

    before do
      allow(client).to receive(:get).with('grids/test-grid/nodes').and_return(
        'nodes' => grid_nodes,
      )
    end

    it 'shows nodes as healthy anddoes not and exit with an error' do
      expect{subject.run([])}.to output_lines [
        ":ok Node node-5 etcd is healthy",
        ":ok Node node-5 etcd is healthy",
      ]
    end
  end
end
