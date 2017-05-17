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

    it 'uses light prompt on simple terminals' do
      expect(ENV).to receive(:[]).with('KONTENA_SIMPLE_TERM').and_return('true')
      expect(Kontena.prompt).to be_kind_of(Kontena::LightPrompt)
    end

    it 'uses fancy prompt on fancy terminals' do
      expect($stdout).to receive(:tty?).at_least(:once).and_return(true)
      expect(ENV).to receive(:[]).with('KONTENA_SIMPLE_TERM').and_return(nil)
      expect(Kontena.prompt).to be_kind_of(TTY::Prompt)
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
