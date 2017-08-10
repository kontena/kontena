describe Kontena::NetworkAdapters::WeaveExecutor, :celluloid => true do
  let(:actor) { described_class.new() }
  subject { actor.wrapped_object }

  describe '#censor_password' do
    it 'removes password' do
      expect(subject.censor_password(['foo', '--password', 'passwd', 'bar'])).to eq(['foo', '--password', '<redacted>', 'bar'])
    end

    it 'does not alter if no --password exist' do
      expect(subject.censor_password(['foo', 'passwd', 'bar'])).to eq(['foo', 'passwd', 'bar'])
    end
  end

  describe '#run' do
    let(:docker_container) { double(:docker_container) }

    before do
      stub_const('Kontena::NetworkAdapters::WeaveExecutor::WEAVE_VERSION', '1.9.3')
    end

    it "runs command in container and logs output" do
      expect(Docker::Container).to receive(:create).with(hash_including(
        'Image' => 'weaveworks/weaveexec:1.9.3',
        'Cmd' => ['--local', 'test', '--opt'],
        'Env' => [
          'HOST_ROOT=/host',
          'VERSION=1.9.3',
          'WEAVE_DEBUG=',
        ],
      )).and_return(docker_container)

      expect(docker_container).to receive(:start!)
      expect(docker_container).to receive(:wait).and_return(
        'StatusCode' => 0,
      )
      expect(docker_container).to receive(:streaming_logs).with(stdout: true, stderr: true)
      expect(docker_container).to receive(:delete).with(force: true, v: true)

      subject.run('test', '--opt')
    end

    it "runs command in container and raises error" do
      expect(Docker::Container).to receive(:create).with(hash_including(
        'Image' => 'weaveworks/weaveexec:1.9.3',
        'Cmd' => ['--local', 'test', '--opt'],
        'Env' => [
          'HOST_ROOT=/host',
          'VERSION=1.9.3',
          'WEAVE_DEBUG=',
        ],
      )).and_return(docker_container)

      expect(docker_container).to receive(:start!)
      expect(docker_container).to receive(:wait).and_return(
        'StatusCode' => 1,
      )
      expect(docker_container).to receive(:streaming_logs).with(stdout: true, stderr: true).and_return('error')
      expect(docker_container).to receive(:delete).with(force: true, v: true)

      expect{subject.run('test', '--opt')}.to raise_error(Kontena::NetworkAdapters::WeaveExecError, 'weaveexec exit 1: ["test", "--opt"]' + "\n" + 'error')
    end

    it "runs command in container and yields lines from stdout" do
      expect(Docker::Container).to receive(:create).with(hash_including(
        'Image' => 'weaveworks/weaveexec:1.9.3',
        'Cmd' => ['--local', 'test', '--opt'],
        'Env' => [
          'HOST_ROOT=/host',
          'VERSION=1.9.3',
          'WEAVE_DEBUG=',
        ],
      )).and_return(docker_container)

      expect(docker_container).to receive(:start!)
      expect(docker_container).to receive(:wait).and_return(
        'StatusCode' => 0,
      )
      expect(docker_container).to receive(:streaming_logs).with(stderr: true).and_return('')
      expect(docker_container).to receive(:streaming_logs).with(stdout: true).and_return("test1\ntest2\n")
      expect(docker_container).to receive(:delete).with(force: true, v: true)

      expect{|b| subject.run('test', '--opt', &b)}.to yield_successive_args("test1\n", "test2\n")
    end
  end

  describe '#weavexec!' do
    it 'returns' do
      expect(subject).to receive(:run).with('test', '--opt')

      actor.weaveexec! 'test', '--opt'
    end

    it 'aborts on errors' do
      expect(subject).to receive(:run).with('test', '--opt').and_raise(Kontena::NetworkAdapters::WeaveExecError.new(['test', '--opt'], 1, "error"))

      expect{actor.weaveexec! 'test', '--opt'}.to raise_error(Kontena::NetworkAdapters::WeaveExecError)
      expect(actor).to_not be_dead
    end

    it 'yields' do
      expect(subject).to receive(:run).with('test', '--opt').and_yield("test1\n").and_yield("test2\n")

      expect{|b| actor.weaveexec! 'test', '--opt', &b}.to yield_successive_args("test1\n", "test2\n")
    end
  end

  describe '#weavexec' do
    it 'returns true when ok' do
      expect(subject).to receive(:run).with('test', '--opt')

      expect(actor.weaveexec 'test', '--opt').to be true
    end

    it 'returns false on errors' do
      expect(subject).to receive(:run).with('test', '--opt').and_raise(Kontena::NetworkAdapters::WeaveExecError.new(['test', '--opt'], 1, "error"))
      expect(subject).to receive(:error).with(Kontena::NetworkAdapters::WeaveExecError)

      expect(actor.weaveexec 'test', '--opt').to be false

      expect(actor).to_not be_dead
    end

    it 'yields' do
      expect(subject).to receive(:run).with('test', '--opt').and_yield("test1\n").and_yield("test2\n")

      expect{|b| actor.weaveexec 'test', '--opt', &b}.to yield_successive_args("test1\n", "test2\n")
    end
  end

  describe '#ps!' do
    it 'parses lines' do
      expect(subject).to receive(:run).with('ps', 'test').and_yield("a b c\n")

      expect{|b| actor.ps!('test', &b)}.to yield_with_args('a', 'b', 'c')
    end
  end
end
