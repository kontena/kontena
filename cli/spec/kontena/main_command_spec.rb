require 'kontena/main_command'

describe Kontena::MainCommand do
  let(:subject) { described_class.new('kontena') }

  describe '--version' do
    it 'outputs the version number and exits' do
      expect do
        expect{subject.run(['--version'])}.to output(/kontena-cli #{Kontena::Cli::VERSION}/).to_stdout
      end.to raise_error(SystemExit) do |exc|
        expect(exc.status).to eq 0
      end
    end
  end

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
end
