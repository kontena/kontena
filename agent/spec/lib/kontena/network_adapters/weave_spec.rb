describe Kontena::NetworkAdapters::Weave, :celluloid => true do
  let(:actor) { described_class.new(start: false) }
  subject { actor.wrapped_object }
  let(:observable) { instance_double(Kontena::Observable) }

  let(:node_info_worker) { instance_double(Kontena::Workers::NodeInfoWorker) }
  let(:node_info_observable) { instance_double(Kontena::Observable) }
  let(:weave_launcher) { instance_double(Kontena::Launchers::Weave) }
  let(:weave_observable) { instance_double(Kontena::Observable) }
  let(:ipam_plugin_launcher) { instance_double(Kontena::Launchers::IpamPlugin) }
  let(:ipam_plugin_observable) { instance_double(Kontena::Observable) }

  let(:weavewait_container) { double(Docker::Container,

  )}
  let(:node_info) { instance_double(Node,
    grid_subnet: '10.81.0.0/16',
    grid_iprange: '10.81.128.0/17',
  )}
  let(:weave_info) { double() }
  let(:ipam_info) { double() }

  let(:ipam_client) { instance_double(Kontena::NetworkAdapters::IpamClient) }
  let(:bridge_ip) { '172.18.42.1' }

  before do
    stub_const('Kontena::NetworkAdapters::Weave::WEAVE_VERSION', '1.9.3')

    allow(Celluloid::Actor).to receive(:[]).with(:node_info_worker).and_return(node_info_worker)
    allow(Celluloid::Actor).to receive(:[]).with(:weave_launcher).and_return(weave_launcher)
    allow(Celluloid::Actor).to receive(:[]).with(:ipam_plugin_launcher).and_return(ipam_plugin_launcher)
    allow(node_info_worker).to receive(:observable).and_return(node_info_observable)
    allow(weave_launcher).to receive(:observable).and_return(weave_observable)
    allow(ipam_plugin_launcher).to receive(:observable).and_return(ipam_plugin_observable)

    allow(subject).to receive(:ipam_client).and_return(ipam_client)
    allow(subject).to receive(:observable).and_return(observable)
  end

  describe '#initialize' do
    it 'calls #start by default' do
      expect_any_instance_of(described_class).to receive(:start)
      described_class.new()
    end
  end

  describe '#start' do
    it 'ensures weavewait and observes' do
      expect(subject).to receive(:ensure_weavewait)

      expect(subject).to receive(:observe).with(node_info_observable, weave_observable, ipam_plugin_observable) do |&block|
        expect(subject).to receive(:update).with(node_info)

        block.call(node_info, weave_info, ipam_info)
      end

      actor.start
    end
  end

  describe '#ensure_weavewait' do
    it 'recognizes existing container' do
      expect(subject).to receive(:inspect_container).with('weavewait-1.9.3').and_return(weavewait_container)
      expect(Docker::Container).to_not receive(:create)

      actor.ensure_weavewait
    end

    it 'creates new container' do
      expect(subject).to receive(:inspect_container).with('weavewait-1.9.3').and_return(nil)

      expect(Docker::Container).to receive(:create).with(
        'name' => 'weavewait-1.9.3',
        'Image' => 'weaveworks/weaveexec:1.9.3',
        'Entrypoint' => ['/bin/false'],
        'Labels' => {
          'weavevolumes' => ''
        },
        'Volumes' => {
          '/w' => {},
          '/w-noop' => {},
          '/w-nomcast' => {}
        },
      )

      actor.ensure_weavewait
    end
  end

  describe '#update' do
    let(:ensure_state) { double() }

    it 'ensures and updates observable' do
      expect(subject).to receive(:ensure).with(node_info).and_return(ensure_state)
      expect(observable).to receive(:update).with(ensure_state)

      actor.update(node_info)
      expect(actor).to be_updated
    end

    it 'logs errors and resets observable' do
      expect(subject).to receive(:ensure).with(node_info).and_raise(RuntimeError, 'test')
      expect(subject).to receive(:error).with(RuntimeError)
      expect(observable).to receive(:reset)

      actor.update(node_info)

      expect(actor).to_not be_updated
    end
  end

  describe '#ensure' do
    it 'ensures the default ipam pool' do
      expect(ipam_client).to receive(:reserve_pool).with('kontena', '10.81.0.0/16', '10.81.128.0/17').and_return(
        'PoolID' => 'kontena',
        'Pool' => '10.81.0.0/16',
      )

      expect(subject.ensure(node_info)).to eq(
        ipam_pool: 'kontena',
        ipam_subnet: '10.81.0.0/16',
      )
    end
  end
end
