require 'kontena/cli/plugins/uninstall_command'

describe Kontena::Cli::Plugins::UninstallCommand do
  let(:subject) { described_class.new([]) }
  let(:uninstaller) { instance_double(Kontena::PluginManager::Uninstaller) }

  context 'for a plugin that is not installed' do
    let(:plugin_name) { 'test' }

    before do
      allow(subject).to receive(:installed?).with(plugin_name).and_return(false)
    end

    it 'exits with error if plugin not found' do
      expect{subject.run(['test'])}.to exit_with_error.and output(/Plugin test has not been installed/).to_stderr
    end
  end

  context 'for an installed plugin' do
    let(:plugin_name) { 'test' }

    before do
      allow(subject).to receive(:installed?).with(plugin_name).and_return(true)
      allow(Kontena::PluginManager::Uninstaller).to receive(:new).with(plugin_name).and_return(uninstaller)
    end

    it 'uninstalls the plugin' do
      expect(uninstaller).to receive(:uninstall)

      subject.run(['test'])
    end

    it 'ignores --force' do
      allow(uninstaller).to receive(:uninstall)

      subject.run(['--force', 'test'])
    end
  end
end
