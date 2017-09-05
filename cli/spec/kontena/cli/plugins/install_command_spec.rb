require 'kontena/cli/plugins/install_command'

describe Kontena::Cli::Plugins::InstallCommand do
  let(:subject) { described_class.new([]) }

  it 'exits with error if plugin not found' do
    expect(subject).to receive(:installer).and_raise(StandardError, 'bar')
    expect{subject.run(['foofoo'])}.to exit_with_error.and output(/StandardError/).to_stderr
  end
end
