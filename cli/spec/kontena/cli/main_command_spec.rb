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
end
