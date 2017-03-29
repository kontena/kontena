require "kontena/cli/stacks/logs_command"

describe Kontena::Cli::Stacks::LogsCommand do
  include ClientHelpers
  include RequirementsHelper

  expect_to_require_current_master
  expect_to_require_current_master_token

  describe '#execute' do
    it 'when stack name not provided, reads it from kontena.yml in current dir' do
      expect(subject).to receive(:default_name).and_call_original
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:readable?).and_return(true)
      expect(File).to receive(:read).with('kontena.yml').and_return("stack: foo/bar")
      expect(client).to receive(:get).and_return('logs' => [{'data' => 'foobar'}])
      expect{subject.run([])}.to output(/foobar/).to_stdout
    end
  end
end

