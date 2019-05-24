
describe Kontena::Launchers::IpamPlugin, :celluloid => true do
  let(:actor) { described_class.new(false) }
  let(:subject) { actor.wrapped_object }
  let(:observable) { instance_double(Kontena::Observable) }

  let(:node_info_worker) { instance_double(Kontena::Workers::NodeInfoWorker) }
  let(:node_info_observable) { instance_double(Kontena::Observable) }
  let(:etcd_launcher) { instance_double(Kontena::Launchers::Etcd) }
  let(:etcd_observable) { instance_double(Kontena::Observable) }

  let(:ipam_client) { instance_double(Kontena::NetworkAdapters::IpamClient) }

  let(:node_info) { instance_double(Node,
    node_number: 1,
    grid_supernet: '10.80.0.0/12',
  ) }

  let(:container_id) { 'd8bcc8b4adfa72673d44d9fa4d2e9520f6286b8bab62f3351bd9fae500fc0856' }
  let(:container_image) { 'kontena/ipam-plugin:0.2.2' }
  let(:container_running?) { true }
  let(:container) { double(Docker::Container,
    id: container_id,
    info: {
      'Config' => {
        'Image' => container_image,
      }
    },
    running?: container_running?,
  )}

  before do
    allow(Celluloid::Actor).to receive(:[]).with(:node_info_worker).and_return(node_info_worker)
    allow(Celluloid::Actor).to receive(:[]).with(:etcd_launcher).and_return(etcd_launcher)
    allow(node_info_worker).to receive(:observable).and_return(node_info_observable)
    allow(etcd_launcher).to receive(:observable).and_return(etcd_observable)

    allow(subject).to receive(:inspect_container).with('kontena-ipam-plugin').and_return(container)
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
    it 'ensures image and observes' do
      expect(subject).to receive(:ensure_image).with('kontena/ipam-plugin:0.2.2')
      expect(subject).to receive(:observe).with(node_info_observable, etcd_observable) do |&block|
        expect(subject).to receive(:update).with(node_info)

        block.call(node_info)
      end

      actor.start
    end
  end

  describe '#update' do
    it 'ensures container and updates observable' do
      expect(subject).to receive(:ensure).with(node_info).and_return({ running: true })
      expect(observable).to receive(:update).with(running: true)

      actor.update(node_info)
    end

    it 'logs errors and resets observable' do
      expect(subject).to receive(:ensure).with(node_info).and_raise(RuntimeError, 'test')
      expect(subject).to receive(:error).with(RuntimeError)
      expect(observable).to receive(:reset)

      actor.update(node_info)
    end
  end

  describe '#healthy?' do
    it 'returns falsey on ipam client errors' do
      expect(ipam_client).to receive(:activate).and_raise(Excon::Errors::Error)

      expect(subject.healthy?).to be_falsey
    end

    it 'returns truthy when ipam client succeeds' do
      expect(ipam_client).to receive(:activate).and_return({ }) # XXX

      expect(subject.healthy?).to be_truthy
    end
  end

  describe '#ensure' do
    it 'recognizes existing containers' do
      expect(subject).to_not receive(:create_container)

      actor.ensure(node_info)
    end

    it 'passes through unexpected Docker errors', :log_celluloid_actor_crashes => false do
      expect(subject).to receive(:inspect_container).and_raise(Docker::Error::ServerError)

      expect{ actor.ensure(node_info) }.to raise_error(Docker::Error::ServerError)
    end
  end

  context 'with missing containers' do
    let(:container) { nil }
    let(:create_container) { double(Docker::Container,
      id: container_id,
      running?: true,
    ) }

    describe '#ensure' do
      it 'creates the containers' do
        expect(Docker::Container).to receive(:create).with(
          'name' => 'kontena-ipam-plugin',
          'Image' => 'kontena/ipam-plugin:0.2.2',
          'Volumes' => {
            '/run/docker/plugins' => {},
            '/var/run/docker.sock' => {}
          },
          'StopSignal' => 'SIGTTIN',
          'Cmd' => ["bundle", "exec", "thin", "-a", "127.0.0.1", "-p", "2275", "-e", "production", "start"],
          'Env' => [
            "LOG_LEVEL=1",
            'ETCD_ENDPOINT=http://127.0.0.1:2379',
            'NODE_ID=1',
            'KONTENA_IPAM_SUPERNET=10.80.0.0/12',
          ],
          'HostConfig' => {
            'NetworkMode' => 'host',
            'RestartPolicy' => {'Name' => 'always'},
            'Binds' => [
              '/run/docker/plugins/:/run/docker/plugins/',
              '/var/run/docker.sock:/var/run/docker.sock'
            ],
          },
        ).and_return(create_container)
        expect(create_container).to receive(:start!)

        actor.ensure(node_info)
      end
    end
  end

  context 'with a stopped container' do
    let(:container_running?) { false }

    describe '#ensure' do
      it 'starts the container' do
        expect(container).to receive(:start!)

        actor.ensure(node_info)
      end
    end
  end

  context 'with an outdated image' do
    let(:create_container) { double(Docker::Container,
      id: container_id,
      running?: true,
    ) }

    describe '#ensure_container' do
      it 're-creates the etcd container' do
        expect(container).to receive(:delete).with(force: true)
        expect(subject).to receive(:create_container).with('kontena/ipam-plugin:0.3.0', Hash).and_return(create_container)

        expect(actor.ensure_container('kontena/ipam-plugin:0.3.0', node_info)).to eq create_container
      end
    end
  end

end
