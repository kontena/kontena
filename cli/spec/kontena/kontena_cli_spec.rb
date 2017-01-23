require_relative '../spec_helper'
require 'kontena_cli'

describe Kontena do
  let(:subject) { described_class }

  describe '#run' do
    let(:whoami) { double(:whoami_command) }

    before(:each) do
      expect(Kontena::MainCommand).to receive(:new).and_call_original
      expect(Kontena::Cli::WhoamiCommand).to receive(:new).and_return(whoami)
      expect(whoami).to receive(:run).with(['--bash-completion-path']).and_return(true)
    end

    it 'accepts a command line as string' do
      subject.run('whoami --bash-completion-path')
    end

    it 'accepts a command line as a list of parameters' do
      subject.run('whoami', '--bash-completion-path')
    end

    it 'accepts a command line as an array' do
      subject.run(['whoami', '--bash-completion-path'])
    end
  end
end
