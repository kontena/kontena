require "kontena/main_command"

describe Kontena::MainCommand do

  let(:subject) { described_class.new(File.basename($0)) }
  describe '#subcommand_missing' do
    it 'suggests plugin install for known plugin commands' do
      expect(subject).to receive(:known_plugin_subcommand?).with('testplugin').and_return(true)
      expect(subject).to receive(:exit_with_error).with(/plugin has not been installed/).and_call_original
      expect{subject.run(['testplugin', 'master', 'create'])}.to exit_with_error
    end

    it 'runs normal error handling for unknown sub commands' do
      expect(subject).to receive(:known_plugin_subcommand?).with('testplugin').and_return(false)
      expect{subject.run(['testplugin', 'master', 'create'])}.to raise_error(Clamp::UsageError)
    end
  end

  context 'for a command that raises RuntimeError' do
    let(:test_fail_command) { Class.new(Kontena::Command) do
      def execute
        fail 'test'
      end
    end}

    before do
      Kontena::MainCommand.subcommand 'test-fail1', "Test failures", test_fail_command
    end

    it 'logs an error and aborts' do
      expect{subject.run(['test-fail1'])}.to raise_error(SystemExit).and output(/\[error\] RuntimeError : test\s+See .* or run the command again with environment DEBUG=true set to see the full exception/m).to_stderr
    end

    context 'with DEBUG' do
      before do
        allow(Kontena).to receive(:debug?).and_return(true)
      end

      it 'lets the error raise through' do
        expect{subject.run(['test-fail1'])}.to raise_error(RuntimeError, 'test')
      end

    end
  end

  context 'for a command that raises StandardError' do
    let(:test_fail_command) { Class.new(Kontena::Command) do
      def execute
        raise Kontena::Errors::StandardError.new(404, "Not Found")
      end
    end}

    before do
      Kontena::MainCommand.subcommand 'test-fail2', "Test failures", test_fail_command
    end

    it 'logs an error and aborts' do
      expect{subject.run(['test-fail2'])}.to raise_error(SystemExit).and output(" [error] 404 : Not Found\n").to_stderr
    end

    context 'with DEBUG' do
      before do
        allow(Kontena).to receive(:debug?).and_return(true)
      end

      it 'lets the error raise through' do
        expect{subject.run(['test-fail2'])}.to raise_error(Kontena::Errors::StandardError)
      end
    end
  end
end
