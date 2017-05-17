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

  describe '#run!' do
    let(:whoami) { double(:whoami) }

    before(:each) do
      expect(Kontena::Cli::WhoamiCommand).to receive(:new).and_return(whoami)
    end

    it 'accepts a command line as string' do
      expect(whoami).to receive(:run).with(['--bash-completion-path']).and_return(true)
      Kontena.run!('whoami --bash-completion-path')
    end

    it 'accepts a command line as a list of parameters' do
      expect(whoami).to receive(:run).with(['--bash-completion-path']).and_return(true)
      Kontena.run!('whoami', '--bash-completion-path')
    end

    it 'accepts a command line as an array' do
      expect(whoami).to receive(:run).with(['--bash-completion-path']).and_return(true)
      Kontena.run!(['whoami', '--bash-completion-path'])
    end

    it 'Returns true if the command exits with SystemExit status 0' do
      expect(whoami).to receive(:run) { exit 0 }
      expect(Kontena.run!(['whoami'])).to be_truthy
    end

    it 'Re-raises the SystemExit when command exits with non-zero status' do
      expect(whoami).to receive(:run) { exit 1 }
      expect{Kontena.run!(['whoami'])}.to exit_with_error.status(1)
    end
  end

  describe '#run' do
    let(:whoami) { double(:whoami) }

    before(:each) do
      expect(Kontena::Cli::WhoamiCommand).to receive(:new).and_return(whoami)
    end

    it 'Returns false when status is 1' do
      expect(whoami).to receive(:run) { exit 1 }
      expect(Kontena.run(['whoami'])).to be_falsey
    end

    it 'Returns true when status is 0' do
      expect(whoami).to receive(:run) { exit 0 }
      expect(Kontena.run(['whoami'])).to be_truthy
    end

    it 'Returns true when nothing was raised' do
      expect(whoami).to receive(:run).and_return(nil)
      expect(Kontena.run(['whoami'])).to be_truthy
    end
  end
end
