
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
        'io.kontena.stack.name' => 'null'
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

  describe '#skip_logs?' do
    it 'return true is skip_logs label is set' do
      allow(subject).to receive(:labels).and_return({
        'io.kontena.container.skip_logs' => '1'
      })
      expect(subject.skip_logs?).to be_truthy
    end

    it 'return false is skip_logs label is not set' do
      allow(subject).to receive(:labels).and_return({})
      expect(subject.skip_logs?).to be_falsey
    end
  end

  describe '#finished?' do
    it 'returns true if container has finished_at timestamp' do
      allow(subject).to receive(:state).and_return({
        'FinishedAt' => Time.now.utc.to_s
      })
      expect(subject.finished?).to be_truthy
    end

    it 'returns false if container is not finished' do
      allow(subject).to receive(:state).and_return({
        'FinishedAt' => '0001-01-01T00:00:00Z'
      })
      expect(subject.finished?).to be_falsey

      allow(subject).to receive(:state).and_return({
      })
      expect(subject.finished?).to be_falsey
    end
  end

  describe '#service_name' do
    it 'return plain service for default stack' do
      expect(subject).to receive(:default_stack?).and_return(true)
      expect(subject).to receive(:labels).and_return({'io.kontena.service.name' => 'service'})

      expect(subject.service_name_for_lb).to eq('service')
    end

    it 'return stackified service for stack based service' do
      expect(subject).to receive(:default_stack?).and_return(false)
      allow(subject).to receive(:labels).and_return({'io.kontena.service.name' => 'service', 'io.kontena.stack.name' => 'stack'})

      expect(subject.service_name_for_lb).to eq('stack-service')
    end

  end
end
