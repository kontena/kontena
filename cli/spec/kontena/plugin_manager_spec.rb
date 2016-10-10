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

  describe 'spec_has_valid_dependency?' do
    before(:each) do
      stub_const('Kontena::PluginManager::MIN_CLI_VERSION', '0.15.99999')
    end

    it 'returns true if spec dependency > than MIN_CLI_VERSION' do
      spec = Gem::Specification.new do |s|
        s.name        = 'kontena-plugin-foo'
        s.version     = '0.1.0'
        s.add_runtime_dependency 'kontena-cli', '>= 0.16.0'
      end
      expect(subject.spec_has_valid_dependency?(spec)).to be_truthy
    end

    it 'returns true if spec dependency > than MIN_CLI_VERSION and is prerelease' do
      spec = Gem::Specification.new do |s|
        s.name        = 'kontena-plugin-foo'
        s.version     = '0.1.0'
        s.add_runtime_dependency 'kontena-cli', '>= 0.16.0.pre2'
      end
      expect(subject.spec_has_valid_dependency?(spec)).to be_truthy
    end

    it 'returns false if spec dependency < than MIN_CLI_VERSION' do
      spec = Gem::Specification.new do |s|
        s.name        = 'kontena-plugin-foo'
        s.version     = '0.1.0'
        s.add_runtime_dependency 'kontena-cli', '>= 0.15.0'
      end
      expect(subject.spec_has_valid_dependency?(spec)).to be_falsey
    end

    it 'returns false if spec dependency < than MIN_CLI_VERSION and is prerelease' do
      spec = Gem::Specification.new do |s|
        s.name        = 'kontena-plugin-foo'
        s.version     = '0.1.0'
        s.add_runtime_dependency 'kontena-cli', '>= 0.15.0.beta1'
      end
      expect(subject.spec_has_valid_dependency?(spec)).to be_falsey
    end
  end
end
