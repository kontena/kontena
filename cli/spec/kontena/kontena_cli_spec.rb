require 'kontena_cli'
require 'kontena/light_prompt'
require 'kontena/cli/whoami_command'

describe Kontena do
  context 'prompt' do
    before(:each) do
      Kontena.reset_prompt
    end

    after(:each) do
      Kontena.reset_prompt
    end

    it 'uses light prompt on windows' do
      allow(ENV).to receive(:[]).with('OS').and_return('Windows_NT')
      expect(Kontena.prompt).to be_kind_of(Kontena::LightPrompt)
    end
  end

  describe '#minor_version' do
    it "returns a version string" do
      expect(Kontena.minor_version).to match /^\d+\.\d+$/
    end
  end

  describe '#run' do
    let(:whoami) { double(:whoami) }

    before(:each) do
      expect(Kontena::Cli::WhoamiCommand).to receive(:new).and_return(whoami)
      expect(whoami).to receive(:run).with(['--bash-completion-path']).and_return(true)
    end

    it 'accepts a command line as string' do
      Kontena.run('whoami --bash-completion-path')
    end

    it 'accepts a command line as a list of parameters' do
      Kontena.run('whoami', '--bash-completion-path')
    end

    it 'accepts a command line as an array' do
      Kontena.run(['whoami', '--bash-completion-path'])
    end
  end
end
