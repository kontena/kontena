require 'kontena/plugin_manager'

describe Kontena::PluginManager::Uninstaller do
  let(:subject) { described_class.new('foo') }
  let(:installed) { double(name: 'double', base_dir: '/tmp') }
  let(:command) { double }

  before(:each) do
    allow(subject).to receive(:installed).with('foo').and_return(installed)
  end

  context '#uninstall' do
    it 'runs the gem uninstaller' do
      expect(subject).to receive(:command).with(installed).and_return(command)
      expect(command).to receive(:uninstall).and_return(true)
      subject.uninstall
    end
  end
end
