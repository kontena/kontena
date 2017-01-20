describe Kontena::Models::NodeInfo do
  let :node_info do
    {
      'grid' => {
        'subnet' => '10.81.0.0/16',
        'trusted_subnets' => [ '192.168.66.0/24' ],
      },
      'overlay_ip' => '10.81.0.1',
      'peer_ips' => [ '192.168.66.102' ],
    }
  end

  subject do
    described_class.new(node_info)
  end

  it "has a grid_subnet" do
    expect(subject.grid_subnet).to be_a IPAddress
    expect(subject.grid_subnet.network.to_s).to eq '10.81.0.0'
    expect(subject.grid_subnet.prefix).to eq 16
    expect(subject.grid_subnet.to_string).to eq '10.81.0.0/16'
  end

  it "has grid_trusted_subnets" do
    expect(subject.grid_trusted_subnets).to eq [ '192.168.66.0/24' ]
  end

  it "has overlay_ip" do
    expect(subject.overlay_ip).to eq '10.81.0.1'
  end
  it "has overlay_cidr" do
    expect(subject.overlay_cidr).to eq '10.81.0.1/16'
  end

  it "has peer_ips" do
    expect(subject.peer_ips).to eq [ '192.168.66.102' ]
  end

  it "is observable" do
    expect(described_class.observable).to be_a Kontena::Actors::Observable
  end

  context "For an observer class" do
    let :observer_class do
      Class.new do
        include Celluloid
        include Kontena::Logging

        def initialize(cls)
          cls.observe :on_node_info
        end

        def on_node_info(node_info)
          @node_info = node_info
        end

        def poll
          @node_info
        end

        def wait
          until @node_info
            sleep 0.1
          end

          return @node_info
        end
      end
    end

    it "does not observe any value if not yet updated", :celluloid => true do
      expect(observer_class.new(described_class).poll).to be_nil
    end

    it "immediately observes an updated value", :celluloid => true do
      described_class.observable.update node_info

      expect(observer_class.new(described_class).poll).to be node_info
    end

    it "waits for an updated value", :celluloid => true do
      observer = observer_class.new(described_class)

      described_class.observable.update node_info

      Timeout.timeout(1) do
        expect(observer.wait).to be node_info
      end
    end
  end
end
