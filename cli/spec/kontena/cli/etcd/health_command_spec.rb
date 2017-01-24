describe Kontena::Cli::Etcd::HealthCommand do
  include ClientHelpers
  include OutputHelpers

  before do
    allow(subject).to receive(:health_icon) {|health| health.inspect }
  end

  describe '#show_node' do
    context "For an offline node" do
      let :node do
        {
          "connected" => false,
          "name" => "node-1",
        }
      end

      it "shows offline and returns false" do
        expect{subject.show_node(node)}.to return_and_output false, [
          "Node node-1 is offline",
        ]
      end
    end

    context "For a node that fails to get health" do
      let :node do
        {
          "name" => "node-1",
          "id" => "testnode",
          "connected" => true,
        }
      end

      before do
        expect(client).to receive(:get).with('nodes/test-grid/testnode/health').and_raise(Kontena::Errors::StandardError.new(503, "timeout"))
      end

      it "shows errored and returns false" do
        expect{subject.show_node(node)}.to return_and_output false, [
          "Node node-1 health error: timeout",
        ]
      end
    end

    context "For a node that returns health" do
      let :node do
        {
          "name" => "node-1",
          "id" => "testnode",
          "connected" => true,
        }
      end

      it "shows healthy and returns true when health" do
        expect(client).to receive(:get).with('nodes/test-grid/testnode/health').and_return({'etcd' => {'health' => true}})

        expect{subject.show_node(node)}.to return_and_output true, [
          "Node node-1 is healthy",
        ]
      end

      it "shows unhealthy and returns false when error" do
        expect(client).to receive(:get).with('nodes/test-grid/testnode/health').and_return({'etcd' => {'error' => "bad"}})

        expect{subject.show_node(node)}.to return_and_output false, [
          "Node node-1 is unhealthy: bad",
        ]
      end
    end
  end
end
