require_relative '../../spec_helper'

describe Docker::Container do

  let(:subject) do
    Docker::Container.new()
  end

  before(:each) do
    allow(subject).to receive(:json).and_return({
      'Config' => {
        'Labels' => {
          'io.kontena.container.name' => 'foo-1'
        }
      },
      'State' => {
        'Running' => true
      },
      'HostConfig' => {
        'Devices' => nil,
        'RestartPolicy' => {'Name' => 'always'}
      }
    })
  end

  describe '#labels' do
    it 'returns labels hash' do
      expect(subject.labels).to include('io.kontena.container.name' => 'foo-1')
    end
  end

  describe '#state' do
    it 'returns State hash' do
      expect(subject.state).to include('Running' => true)
    end
  end

  describe '#host_config' do
    it 'returns HostConfig hash' do
      expect(subject.host_config).to include('Devices' => nil)
    end
  end

  describe '#config' do
    it 'returns Config hash' do
      expect(subject.config.keys).to include('Labels')
    end
  end

  describe '#restart_policy' do
    it 'returns HostConfig.RestartPolicy hash' do
      expect(subject.restart_policy).to include('Name' => 'always')
    end
  end

  describe '#load_balanced?' do
    it 'returns true if load balanced' do
      allow(subject).to receive(:labels).and_return({
        'io.kontena.load_balancer.name' => 'lb'
      })
      expect(subject.load_balanced?).to be_truthy
    end

    it 'returns false by default' do
      expect(subject.load_balanced?).to be_falsey
    end
  end

  describe '#suspiciously_dead?' do
    it 'returns false if not dead' do
      allow(subject).to receive(:state).and_return({'Dead' => false})
      expect(subject.suspiciously_dead?).to be_falsey
    end

    it 'returns false if dead but non-suspicious exit code' do
      allow(subject).to receive(:state).and_return({
        'Dead' => true, 'ExitCode' => -1
      })
      expect(subject.suspiciously_dead?).to be_falsey
    end

    it 'returns true if suspiciously dead' do
      allow(subject).to receive(:state).and_return({
        'Dead' => true, 'ExitCode' => Docker::Container::SUSPICIOUS_EXIT_CODES[0]
      })
      expect(subject.suspiciously_dead?).to be_truthy
    end
  end

  describe '#default_stack?' do
    it 'returns true if container is part of default stack' do
      allow(subject).to receive(:labels).and_return({
        'io.kontena.service.id' => 'aaa',
        'io.kontena.stack.name' => 'default'
      })
      expect(subject.default_stack?).to be_truthy
    end

    it 'returns false if container is not part of default stack' do
      allow(subject).to receive(:labels).and_return({
        'io.kontena.service.id' => 'aaa',
        'io.kontena.stack.name' => 'other'
      })
      expect(subject.default_stack?).to be_falsey
    end

    it 'returns true if container is missing stack info' do
      allow(subject).to receive(:labels).and_return({
        'io.kontena.service.id' => 'aaa'
      })
      expect(subject.default_stack?).to be_truthy
    end

    it 'returns false if container is not part of a service' do
      allow(subject).to receive(:labels).and_return({})
      expect(subject.default_stack?).to be_falsey
    end
  end
end
