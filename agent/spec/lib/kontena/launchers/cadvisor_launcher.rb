describe Kontena::Launchers::Cadvisor, :celluloid => true do
  let(:actor) { described_class.new(false) }
  let(:subject) { actor.wrapped_object }

  let(:container_id) { 'd8bcc8b4adfa72673d44d9fa4d2e9520f6286b8bab62f3351bd9fae500fc0856' }
  let(:container_image) { 'google/cadvisor:v0.24.1' }
  let(:container_labels_version) { '1.4.0-dev' }
  let(:container_running?) { true }
  let(:container) { double(Docker::Container,
    id: container_id,
    info: {
      'Config' => {
        'Image' => container_image,
        'Labels' => {
          'io.kontena.agent.version' => container_labels_version,
        },
      }
    },
    running?: container_running?,
  )}

  before do
    stub_const('Kontena::Agent::VERSION', '1.4.0-dev')

    allow(subject).to receive(:inspect_container).with('kontena-cadvisor').and_return(container)
  end

  describe '#initialize' do
    it 'calls #start by default' do
      expect_any_instance_of(described_class).to receive(:start)
      described_class.new()
    end
  end

  describe '#start' do
    it 'ensures image and container' do
      expect(subject).to receive(:ensure_image).with('google/cadvisor:v0.24.1')
      expect(subject).to receive(:ensure_container).with('google/cadvisor:v0.24.1')

      actor.start
    end

    context 'with CADVISOR_DISABLED' do
      before do
        allow(ENV).to receive(:[]).with('CADVISOR_DISABLED').and_return('true')
      end

      it 'logs a warning and does nothing' do
        expect(subject).to receive(:warn).with('cadvisor is disabled')
        expect(subject).to_not receive(:ensure_image)
        expect(subject).to_not receive(:ensure_container)

        actor.start
      end
    end
  end

  describe '#ensure_container' do
    it 'recognizes existing containers' do
      expect(subject).to_not receive(:create_container)

      actor.ensure_container('google/cadvisor:v0.24.1')
    end

    it 'passes through unexpected Docker errors', :log_celluloid_actor_crashes => false do
      expect(subject).to receive(:inspect_container).and_raise(Docker::Error::ServerError)

      expect{ actor.ensure_container('google/cadvisor:v0.24.1') }.to raise_error(Docker::Error::ServerError)
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
          'name' => 'kontena-cadvisor',
          'Image' => 'google/cadvisor:v0.24.1',
          'Cmd' => [
            '--docker_only',
            '--listen_ip=127.0.0.1',
            '--port=8989',
            '--storage_duration=2m',
            '--housekeeping_interval=10s',
            '--disable_metrics=tcp,disk'
          ],
          'Labels' => {
            'io.kontena.agent.version' => '1.4.0-dev',
          },
          'Volumes' => {
              '/rootfs' => {},
              '/var/run' => {},
              '/sys' => {},
              '/var/lib/docker' => {},
          },
          'HostConfig' => {
            'NetworkMode' => 'host',
            'RestartPolicy' => {'Name' => 'always'},
            'CpuShares' => 128,
            'Memory' => (256 * 1024 * 1024),
            'Binds' => [
              '/:/rootfs:ro,rshared',
              '/var/run:/var/run:rshared',
              '/sys:/sys:ro,rshared',
              '/var/lib/docker:/var/lib/docker:ro,rshared',
            ],
          },
        ).and_return(create_container)
        expect(create_container).to receive(:start!)

        actor.ensure_container('google/cadvisor:v0.24.1')
      end
    end
  end

  context 'with a stopped container' do
    let(:container_running?) { false }

    describe '#ensure' do
      it 'starts the container' do
        expect(container).to receive(:start!)

        actor.ensure_container('google/cadvisor:v0.24.1')
      end
    end
  end

  context 'with an outdated image' do
    let(:container_image) { 'google/cadvisor:v0.23.0' }
    let(:create_container) { double(Docker::Container,
      id: container_id,
      running?: true,
    ) }

    describe '#ensure_container' do
      it 're-creates the container' do
        expect(container).to receive(:delete).with(force: true)
        expect(subject).to receive(:create_container).with('google/cadvisor:v0.24.1', Hash).and_return(create_container)

        expect(actor.ensure_container('google/cadvisor:v0.24.1')).to eq create_container
      end
    end
  end

  context 'with an outdated agent version' do
    let(:container_labels_version) { '1.3.4' }
    let(:create_container) { double(Docker::Container,
      id: container_id,
      running?: true,
    ) }

    describe '#ensure_container' do
      it 're-creates the container' do
        expect(container).to receive(:delete).with(force: true)
        expect(subject).to receive(:create_container).with('google/cadvisor:v0.24.1', Hash).and_return(create_container)

        expect(actor.ensure_container('google/cadvisor:v0.24.1')).to eq create_container
      end
    end
  end

  describe '#volume_mappings' do
    it 'returns correct volume mappings' do
      expect(subject.volume_mappings.keys).to eq(['/rootfs', '/var/run', '/sys', '/var/lib/docker'])
    end
  end

  describe '#cadvisor_enabled?' do
    it 'returns true by default' do
      expect(subject.cadvisor_enabled?).to be_truthy
    end

    it 'returns false if disabled by env variable' do
      allow(ENV).to receive(:[]).with('CADVISOR_DISABLED').and_return('true')
      expect(subject.cadvisor_enabled?).to be_falsey
    end
  end
end
