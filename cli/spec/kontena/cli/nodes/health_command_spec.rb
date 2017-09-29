require 'kontena/cli/nodes/health_command'

describe Kontena::Cli::Nodes::HealthCommand do
  include ClientHelpers
  include OutputHelpers

  let(:connected_at) { (Time.now - 50.0).to_s }

  before do
    allow(subject).to receive(:health_icon) {|health| health.inspect }
    allow(subject).to receive(:time_since).with(connected_at).and_return('50s')
  end

  context "for an online node" do
    let :node_health do
      {
        "name" => "node",
        "node_number" => 4,
        "initial_member" => false,
        'status' => 'online',
        'connected_at' => connected_at,
        "connected" => true,
        'etcd_health' => {
          'health' => true,
          'error' => nil,
        },
      }
    end

    before do
      allow(client).to receive(:get).with('nodes/test-grid/node/health').and_return(node_health)
    end

    it "outputs ok" do
      expect{subject.run(['node'])}.to output_lines [
        ":ok Node is online for 50s",
        ":ok Node node etcd is healthy",
      ]
    end
  end

  context "for an offline node" do
    let :node_errors do
      {
        'connection' => "Websocket disconnected at 2017-07-12 12:28:10 UTC with code 4030: ping timeout after 5.00s",
      }
    end

    before do
      allow(client).to receive(:get).with('nodes/test-grid/node/health').and_raise(Kontena::Errors::StandardErrorHash.new(422, "", node_errors))
    end

    it "fails as error" do
      expect{subject.run(['node'])}.to exit_with_error.and output_lines [
        ":offline Node test-grid/node connection error: Websocket disconnected at 2017-07-12 12:28:10 UTC with code 4030: ping timeout after 5.00s",
      ]
    end
  end

  context "for an online initial node in an ok grid" do
    let :node_health do
      {
        "name" => "node",
        "node_number" => 1,
        "initial_member" => true,
        'status' => 'online',
        'connected_at' => connected_at,
        "connected" => true,
        'etcd_health' => {
          'health' => true,
          'error' => nil,
        },
      }
    end

    before do
      allow(client).to receive(:get).with('nodes/test-grid/node/health').and_return(node_health)
    end

    it "outputs ok" do
      expect{subject.run(['node'])}.to output_lines [
        ":ok Node is online for 50s",
        ":ok Node node etcd is healthy",
      ]
    end
  end

  context "for an online node in an grid with broken etcd" do
    let :node_health do
      {
        "name" => "node",
        "node_number" => 4,
        "initial_member" => false,
        'status' => 'online',
        'connected_at' => connected_at,
        "connected" => true,
        'etcd_health' => {
          'health' => false,
          'error' => "no peers reachable",
        },
      }
    end

    before do
      allow(client).to receive(:get).with('nodes/test-grid/node/health').and_return(node_health)
    end

    it "fails with etcd errro" do
      expect{subject.run(['node'])}.to exit_with_error.and output_lines [
        ":ok Node is online for 50s",
        ":error Node node etcd is unhealthy: no peers reachable",
      ]
    end
  end
end
