
describe Kontena::Launchers::Cadvisor do

  let(:subject) { described_class.new(false) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'calls #start by default' do
      expect_any_instance_of(described_class).to receive(:start)
      subject = described_class.new
      sleep 0.01
    end
  end

  describe '#start' do
    it 'pulls image and creates a container' do
      expect(subject.wrapped_object).to receive(:pull_image).with(subject.image)
      expect(subject.wrapped_object).to receive(:create_container).with(subject.image)
      subject.start
    end

    it 'retries 4 times if Docker::Error::ServerError is raised' do
      allow(subject.wrapped_object).to receive(:start_cadvisor) do
        raise Docker::Error::ServerError
      end
      expect(subject.wrapped_object).to receive(:start_cadvisor).exactly(5).times
      subject.start
      sleep 0.01
    end

    it 'does not start if cadvisor is disabled' do
      allow(ENV).to receive(:[]).with('CADVISOR_DISABLED').and_return('true')
      expect(subject.wrapped_object).not_to receive(:pull_image)
      expect(subject.wrapped_object).not_to receive(:create_container)
      subject.start
      sleep 0.01
    end
  end

  describe '#volume_mappings' do
    it 'returns correct volume mappings' do
      allow(subject.wrapped_object).to receive(:kontena_image?).and_return(false)
      expect(subject.volume_mappings.keys).to eq(['/rootfs', '/var/run', '/sys', '/var/lib/docker'])
    end
  end

  describe '#config_changed?' do
    it 'returns false if config has not changed' do
      container = double(:cadvisor,
        config: { 'Image' => subject.image },
        labels: { 'io.kontena.agent.version' => Kontena::Agent::VERSION }
      )
      expect(subject.config_changed?(container)).to be_falsey
    end

    it 'returns true if image has changed' do
      container = double(:cadvisor,
        config: { 'Image' => 'foo/cadvisor:0.24.1' },
        labels: { 'io.kontena.agent.version' => Kontena::Agent::VERSION }
      )
      expect(subject.config_changed?(container)).to be_truthy
    end

    it 'returns true if agent version has changed' do
      container = double(:cadvisor,
        config: { 'Image' => subject.image },
        labels: { 'io.kontena.agent.version' => "#{Kontena::Agent::VERSION}-special-edition" }
      )
      expect(subject.config_changed?(container)).to be_truthy
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
