require 'kontena/plugin_manager'

describe Kontena::PluginManager::Installer do
  context 'default version' do
    let(:subject) { described_class.new('foo') }
    let(:command) { double }

    before(:each) do
      allow(subject).to receive(:command).and_return(command)
    end

    context '#install' do
      it 'runs the installer' do
        expect(command).to receive(:install).with('kontena-plugin-foo', Gem::Requirement.default).and_return(true)
        expect(command).to receive(:installed_gems).and_return([])
        subject.install
      end
    end
  end

  context 'specific version' do
    let(:subject) { described_class.new('foo', version: '0.1.2') }
    let(:command) { double }

    before(:each) do
      allow(subject).to receive(:command).and_return(command)
    end

    context '#install' do
      it 'runs the installer' do
        version = double
        expect(Gem::Requirement).to receive(:new).with('0.1.2').and_return(version)
        expect(command).to receive(:install).with('kontena-plugin-foo', version).and_return(true)
        allow(command).to receive(:installed_gems).and_return([])
        subject.install
      end
    end
  end

  context 'pre-release version' do
    let(:subject) { described_class.new('foo', pre: true) }

    context '#command' do
      it 'receives new with prerelease true' do
        expect(Gem::DependencyInstaller).to receive(:new).with(hash_including(prerelease: true)).and_return(true)
        subject.command
      end
    end
  end
end
