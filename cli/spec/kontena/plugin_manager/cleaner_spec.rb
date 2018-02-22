require 'kontena/plugin_manager'

describe Kontena::PluginManager::Cleaner do
  let(:subject) { described_class.new('foo') }
  let(:command) { double(handle_options: anything) }

  before(:each) do
    allow(subject).to receive(:command).and_return(command)
  end

  it 'returns true if the rubygems cleanup command exits with 0' do
    expect(command).to receive(:execute).and_raise(Gem::SystemExitException, 0)
    expect(subject.cleanup).to be_truthy
  end

  it 'raises the exception if the rubygems cleanup command exits with non-zero' do
    expect(command).to receive(:execute).and_raise(Gem::SystemExitException, 1)
    expect{subject.cleanup}.to raise_error(Gem::SystemExitException)
  end
end
