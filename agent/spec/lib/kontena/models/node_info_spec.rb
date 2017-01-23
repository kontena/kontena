describe Kontena::Models::NodeInfo do
  let :node_info do
    {
      'version' => '1.1-dev',
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

  it "has a version" do
    expect(subject.version).to eq '1.1-dev'
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

  describe Kontena::Models::NodeInfo::Actor, :celluloid => true do
    let :actor do
      described_class.new
    end

    it "updates on agent:node_info" do
      subject = actor.wrapped_object

      Celluloid::Notifications.publish('agent:node_info', node_info)

      observer = Class.new {
        include Celluloid
        include Kontena::Actors::Observer

        attr_accessor :node_info

        def initialize(observable)
          observe node_info: observable
        end
      }.new(actor)

      expect(observer.node_info).to_not be_nil
      expect(observer.node_info.version).to eq '1.1-dev'
    end

  end
end
