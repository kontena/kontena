require_relative '../spec_helper'
require 'kontena_cli'

describe Kontena::PluginManager do

  let(:subject) { described_class.instance }

  describe '#load_plugins' do
    it 'includes hello plugin' do
      plugins = subject.load_plugins
      expect(plugins.any?{ |p| p.name == 'kontena-plugin-hello' }).to be_truthy
    end

    it 'allows plugin to register as a sub-command' do
      plugins = subject.load_plugins
      main = Kontena::MainCommand.new(File.basename($0))
      expect {
        main.run(['hello'])
      }.to raise_error(Clamp::HelpWanted)
    end
  end
end
