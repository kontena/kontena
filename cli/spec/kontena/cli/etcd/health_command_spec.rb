require 'kontena/cli/etcd/health_command'

describe Kontena::Cli::Etcd::HealthCommand do
  include ClientHelpers
  include OutputHelpers

  before do
    allow(subject).to receive(:health_icon) {|health| health.inspect }
  end

  describe '#show_node_health' do
    context "For an offline node" do
      let :node_health do
        {
          "connected" => false,
          "name" => "node-1",
          'etcd_health' => {
            'health' => nil,
            'error' => nil,
          },
        }
      end

      it "shows offline and returns false" do
        expect{subject.show_node_health(node_health)}.to return_and_output false, [
          ":offline Node node-1 is offline",
        ]
      end
    end

    context "For a node with health errors" do
      let :node_health do
        {
          "name" => "node-1",
          "connected" => true,
          'etcd_health' => {
            'health' => nil,
            'error' => "timeout",
          },
        }
      end

      it "shows errored and returns false" do
        expect{subject.show_node_health(node_health)}.to return_and_output false, [
          ":error Node node-1 is unhealthy: timeout",
        ]
      end
    end

    context "For a node that returns health=false" do
      let :node_health do
        {
          "name" => "node-1",
          "connected" => true,
          'etcd_health' => {
            'health' => false,
            'error' => nil,
          },
        }
      end

      it "shows unhealthy and returns false" do
        expect{subject.show_node_health(node_health)}.to return_and_output false, [
          ":error Node node-1 is unhealthy",
        ]
      end
    end

    context "For a healthy node" do
      let :node_health do
        {
          "name" => "node-1",
          "connected" => true,
          'etcd_health' => {
            'health' => true,
            'error' => nil,
          },
        }
      end


      it "shows healthy and returns true" do
        expect{subject.show_node_health(node_health)}.to return_and_output true, [
          ":ok Node node-1 is healthy",
        ]
      end
    end
  end
end
