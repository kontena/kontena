require 'kontena/cli/nodes/list_command'

describe Kontena::Cli::Nodes::ListCommand do
  include ClientHelpers
  include OutputHelpers

  let(:subject) { described_class.new("kontena") }

  before do
    allow(subject).to receive(:health_icon) {|health| health.inspect }
    allow(subject).to receive(:client).and_return(client)
  end

  def time_ago(offset)
    (Time.now.utc - offset).strftime('%FT%T.%NZ')
  end

  context "For a initial_size=1 grid" do
    before do
      allow(client).to receive(:get).with('grids/test-grid').and_return(
        {
          "id" => "test-grid",
          "name" => "test-grid",
          "initial_size" => 1,
          "node_count" => 1,
        }
      )
    end

    context "with initializing and connecting nodes" do
      before do
        allow(client).to receive(:get).with('grids/test-grid/nodes').and_return(
          { "nodes" => [
              # connected node
              {
                "id" => 'test-grid/node-1',
                "node_id" => 'AAAA:AAAA',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => nil,
                "updated" => true,
                "status" => "online",
                "name" => "node-1",
                "node_number" => 1,
                "initial_member" => true,
                'agent_version' => '1.4.0.dev',
              },
              # node was created, not connected yet
              {
                "id" => 'test-grid/node-2',
                "node_id" => nil,
                "connected" => false,
                'connected_at' => nil,
                'disconnected_at' => nil,
                "updated" => false,
                "status" => "created",
                "name" => "node-2",
                "node_number" => 2,
                "initial_member" => false,
                'agent_version' => nil,
              },
              # node was just created when connecting, but not yet connected
              {
                "id" => 'test-grid/CCCC:CCCC',
                "node_id" => 'CCCC:CCCC',
                "connected" => true,
                'connected_at' => nil,
                'disconnected_at' => nil,
                "updated" => false,
                "status" => "offline",
                "name" => nil,
                "node_number" => 3,
                "initial_member" => false,
                'agent_version' => '1.4.0.dev',
              },
              # node has just connected, but not sent any node_info yet
              {
                "id" => 'test-grid/node-4',
                "node_id" => 'DDDD:DDDD',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => time_ago(120.0),
                "updated" => false,
                "status" => "connecting",
                "name" => "node-4",
                "node_number" => 4,
                "initial_member" => false,
                'agent_version' => '1.4.0.dev',
              },
            ]
          }
        )
      end

      it "outputs nodes" do
        expect{subject.run([])}.to output_table [
          [':ok node-1',      '1.4.0.dev', 'online 1m',    '1 / 1', '-'],
          [':offline node-2', '-',         'created',       '-',     '-'],
          [':ok CCCC:CCCC',   '1.4.0.dev', 'offline',       '-',     '-'],
          [':ok node-4',      '1.4.0.dev', 'connecting 1m', '-',     '-'],
        ]
      end
    end

    context "with a draining node" do
      before do
        allow(client).to receive(:get).with('grids/test-grid/nodes').and_return(
          { "nodes" => [
              # draining node
              {
                "id" => 'test-grid/node-1',
                "node_id" => 'AAAA:AAAA',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => nil,
                "updated" => true,
                "status" => "drain",
                "name" => "node-1",
                "node_number" => 1,
                "initial_member" => true,
                'agent_version' => '1.4.0.dev',
              },
            ]
          }
        )
      end

      it "outputs nodes" do
        expect{subject.run([])}.to output_table [
          [':ok node-1',      '1.4.0.dev', 'drain',      '1 / 1', '-'],
        ]
      end
    end
  end

  context "For a initial_size=3 grid" do
    before do
      allow(client).to receive(:get).with('grids/test-grid').and_return(
        {
          "id" => "test-grid",
          "name" => "test-grid",
          "initial_size" => 3,
          "node_count" => 1,
        }
      )
    end

    context "with a single online node" do
      before do
        allow(client).to receive(:get).with('grids/test-grid/nodes').and_return(
          {
            'nodes' => [
              {
                "id" => 'testAAA',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => nil,
                "updated" => true,
                "status" => "online",
                "name" => "node-1",
                "node_number" => 1,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              }
            ]
          }
        )
      end

      it "outputs node with error" do
        expect{subject.run([])}.to output_table [
          [':error node-1', '1.1-dev', 'online 1m', '1 / 3', '-'],
        ]
      end
    end

    context "with one online and one offline node" do
      before do
        allow(client).to receive(:get).with('grids/test-grid/nodes').and_return(
          { "nodes" => [
              {
                "id" => 'testAAA',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => nil,
                "updated" => true,
                "status" => "online",
                "name" => "node-1",
                "node_number" => 1,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
              {
                "id" => 'testBBB',
                "connected" => false,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => time_ago(120.0),
                "updated" => false,
                "status" => "offline",
                "name" => "node-2",
                "node_number" => 2,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
            ]
          }
        )
      end

      it "outputs online node with error" do
        expect{subject.run([])}.to output_table [
          [':error node-1', '1.1-dev', 'online 1m', '1 / 3', '-'],
          [':offline node-2', '1.1-dev', 'offline 2m', '2 / 3', '-'],
        ]
      end
    end

    context "with two online nodes" do
      before do
        allow(client).to receive(:get).with('grids/test-grid/nodes').and_return(
          { "nodes" => [
              {
                "id" => 'testAAA',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => nil,
                "updated" => true,
                "status" => "online",
                "name" => "node-1",
                "node_number" => 1,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
              {
                "id" => 'testBBB',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => time_ago(120.0),
                "updated" => true,
                "status" => "online",
                "name" => "node-2",
                "node_number" => 2,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
            ]
          }
        )
      end

      it "outputs both nodes with warning" do
        expect{subject.run([])}.to output_table [
          [':warning node-1', '1.1-dev', 'online 1m', '1 / 3', '-'],
          [':warning node-2', '1.1-dev', 'online 1m', '2 / 3', '-'],
        ]
      end
    end

    context "with two online nodes and one offline node" do
      before do
        allow(client).to receive(:get).with('grids/test-grid/nodes').and_return(
          { "nodes" => [
              {
                "id" => 'testAAA',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => nil,
                "updated" => true,
                "status" => "online",
                "name" => "node-1",
                "node_number" => 1,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
              {
                "id" => 'testBBB',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => time_ago(120.0),
                "updated" => true,
                "status" => "online",
                "name" => "node-2",
                "node_number" => 2,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
              {
                "id" => 'testCCC',
                "connected" => false,
                'connected_at' => time_ago(360.0),
                'disconnected_at' => time_ago(120.0),
                "updated" => true,
                "status" => "offline",
                "name" => "node-3",
                "node_number" => 3,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
            ]
          }
        )
      end

      it "outputs two nodes with warning and one offline" do
        expect{subject.run([])}.to output_table [
          [':warning node-1', '1.1-dev', 'online 1m',  '1 / 3', '-'],
          [':warning node-2', '1.1-dev', 'online 1m',  '2 / 3', '-'],
          [':offline node-3', '1.1-dev', 'offline 2m', '3 / 3', '-'],
        ]
      end
    end

    context "with two online initial nodes and one non-initial node" do
      before do
        allow(client).to receive(:get).with('grids/test-grid/nodes').and_return(
          {
            "nodes" => [
              {
                "id" => 'testAAA',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => nil,
                "updated" => true,
                "status" => "online",
                "name" => "node-1",
                "node_number" => 1,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
              {
                "id" => 'testBBB',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => time_ago(120.0),
                "updated" => true,
                "status" => "online",
                "name" => "node-2",
                "node_number" => 2,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
              {
                "id" => 'testDDD',
                "connected" => true,
                'connected_at' => time_ago(120.0),
                'disconnected_at' => nil,
                "updated" => true,
                "status" => "online",
                "name" => "node-4",
                "node_number" => 4,
                "initial_member" => false,
                'agent_version' => '1.1-dev',
              },
            ]
          }
        )
      end

      it "outputs two nodes with warning and one online" do
        expect{subject.run([])}.to output_table [
          [':warning node-1', '1.1-dev', 'online 1m',  '1 / 3', '-'],
          [':warning node-2', '1.1-dev', 'online 1m',  '2 / 3', '-'],
          [':ok node-4', '1.1-dev', 'online 2m', '-', '-'],
        ]
      end
    end

    context "with three online initial nodes" do
      before do
        allow(client).to receive(:get).with('grids/test-grid/nodes').and_return(
          {
            "nodes" => [
              {
                "id" => 'testAAA',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => nil,
                "updated" => true,
                "status" => "online",
                "name" => "node-1",
                "node_number" => 1,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
              {
                "id" => 'testBBB',
                "connected" => true,
                'connected_at' => time_ago(60.0),
                'disconnected_at' => time_ago(120.0),
                "updated" => true,
                "status" => "online",
                "name" => "node-2",
                "node_number" => 2,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
              {
                "id" => 'testCCC',
                "connected" => true,
                'connected_at' => time_ago(3630.0),
                'disconnected_at' => time_ago(7203.0),
                "updated" => true,
                "status" => "online",
                "name" => "node-3",
                "node_number" => 3,
                "initial_member" => true,
                'agent_version' => '1.1-dev',
              },
            ]
          }
        )
      end

      it "outputs three nodes with ok" do
        expect{subject.run([])}.to output_table [
          [':ok node-1', '1.1-dev', 'online 1m', '1 / 3', '-'],
          [':ok node-2', '1.1-dev', 'online 1m', '2 / 3', '-'],
          [':ok node-3', '1.1-dev', 'online 1h', '3 / 3', '-'],
        ]
      end
    end
  end
end
