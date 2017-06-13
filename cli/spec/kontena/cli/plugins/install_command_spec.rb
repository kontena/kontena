require 'kontena/cli/plugins/install_command'

describe Kontena::Cli::Plugins::InstallCommand do
  let(:subject) { described_class.new([]) }

  it 'exits with error if plugin not found' do
    expect(Kontena::PluginManager.instance).to receive(:install_plugin).and_raise(StandardError, 'bar')
    expect{subject.run(['foofoo'])}.to exit_with_error.and output(/Install failed/).to_stderr
  end
end
